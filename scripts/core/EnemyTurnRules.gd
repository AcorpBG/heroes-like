class_name EnemyTurnRules
extends RefCounted
const TownDevelopment = preload("res://scripts/core/TownDevelopmentRules.gd")

const TurnPlayback = preload("res://scripts/core/OverworldTurnPlayback.gd")

const LevelRules = preload("res://scripts/core/OverworldLevelRules.gd")
const PlayerRules = preload("res://scripts/core/PlayerIdentityRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const EnemyAdventureRulesScript = preload("res://scripts/core/EnemyAdventureRules.gd")
const AiHeroRulesScript = preload("res://scripts/core/AiHeroRules.gd")
# Computer-player state AiHeroRules keeps between days.
const AI_PLAYER_STATE_KEYS := ["ai_start_hero_granted", "ai_opening_granted", "ai_tavern", "ai_hero_counter", "ai_explored", "ai_boat_wanted_day"]
static var TownRulesScript: Variant = load("res://scripts/core/TownRules.gd")
static var OverworldRulesScript: Variant = load("res://scripts/core/OverworldRules.gd")

const TRACKED_RESOURCES := [
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
const REBUILD_PRESSURE_LAUNCH_WINDOW_DAYS := 5

static func _scenario_factory() -> Variant:
	return load("res://scripts/core/ScenarioFactory.gd")

static func build_enemy_states(configs: Variant) -> Array:
	var states = []
	if not (configs is Array):
		return states

	for config in configs:
		if not (config is Dictionary):
			continue
		states.append(
			{
				"faction_id": String(config.get("faction_id", "")),
				"pressure": 0,
				"raid_counter": 0,
				"commander_counter": 0,
				"siege_progress": 0,
				"treasury": _blank_resource_pool(),
				"posture": "probing",
				"captured_artifact_ids": [],
				"commander_roster": [],
			}
		)
		for key in ["player_id", "player_slot", "team_id"]:
			if config.has(key):
				states[-1][key] = config[key]
	return states

static func normalize_enemy_states(session: SessionStateStoreScript.SessionData) -> void:
	if session == null or session.scenario_id == "":
		return
	# Roster entries built during this normalization are reused within it (see
	# EnemyAdventureRules._normalize_commander_roster_entries); the outermost
	# call owns the memo and drops it at the end, even when the body stops on
	# a script error.
	var owns_entry_memo := not session.has_meta(EnemyAdventureRulesScript.COMMANDER_ENTRY_MEMO_META)
	if owns_entry_memo:
		session.set_meta(EnemyAdventureRulesScript.COMMANDER_ENTRY_MEMO_META, {})
	_normalize_enemy_states_body(session)
	if owns_entry_memo:
		session.remove_meta(EnemyAdventureRulesScript.COMMANDER_ENTRY_MEMO_META)

static func _normalize_enemy_states_body(session: SessionStateStoreScript.SessionData) -> void:
	DifficultyRulesScript.normalize_session(session)

	var configs = _enemy_faction_configs_for_session(session)
	var existing_states = session.overworld.get("enemy_states", [])
	var normalized_states = []

	if configs is Array:
		for config in configs:
			if not (config is Dictionary):
				continue
			var faction_id = PlayerRules.controller_id(config)
			var existing_state = _find_state(existing_states, faction_id)
			var normalized_state := {
				"faction_id": String(config.get("faction_id", "")),
				"pressure": max(0, int(existing_state.get("pressure", 0))),
				"raid_counter": max(0, int(existing_state.get("raid_counter", 0))),
				"commander_counter": max(0, int(existing_state.get("commander_counter", 0))),
				"siege_progress": max(0, int(existing_state.get("siege_progress", 0))),
				"treasury": _normalize_resource_pool(existing_state.get("treasury", {})),
				"posture": _normalize_posture(existing_state.get("posture", "probing")),
				"captured_artifact_ids": _normalize_string_array(existing_state.get("captured_artifact_ids", [])),
				"commander_roster": EnemyAdventureRulesScript.normalize_commander_roster(
					session,
					faction_id,
					existing_state.get("commander_roster", [])
				),
			}
			for key in ["player_id", "player_slot", "team_id"]:
				if config.has(key):
					normalized_state[key] = config[key]
			var rebuild_pressure_request := _normalize_rebuild_pressure_request(
				existing_state.get("rebuild_pressure_request", {}),
				int(session.day)
			)
			if not rebuild_pressure_request.is_empty():
				normalized_state["rebuild_pressure_request"] = rebuild_pressure_request
			var recent_rebuild_targets := _normalize_string_array(
				existing_state.get("recent_rebuild_exploration_target_ids", [])
			)
			while recent_rebuild_targets.size() > EnemyAdventureRulesScript.RAID_RECENT_EXPLORATION_TARGET_LIMIT:
				recent_rebuild_targets.pop_front()
			if not recent_rebuild_targets.is_empty():
				normalized_state["recent_rebuild_exploration_target_ids"] = recent_rebuild_targets
			var known_world_memory := EnemyAdventureRulesScript.normalize_enemy_known_world_memory(
				existing_state.get("known_world_memory", {}),
				int(session.day)
			)
			if not known_world_memory.is_empty():
				normalized_state["known_world_memory"] = known_world_memory
			if existing_state.has("hero_task_state"):
				var task_state_report := normalize_optional_hero_task_state(existing_state.get("hero_task_state", {}))
				if bool(task_state_report.get("ok", false)) and bool(task_state_report.get("normalized_present", false)):
					normalized_state["hero_task_state"] = task_state_report.get("task_state", {})
			for key in AI_PLAYER_STATE_KEYS:
				if existing_state.has(key):
					normalized_state[key] = existing_state[key]
			normalized_states.append(normalized_state)

	session.overworld["enemy_states"] = normalized_states
	EnemyAdventureRulesScript.normalize_raid_armies(session)
	# Older saves carry raid hosts; they continue as heroes (or disband).
	AiHeroRulesScript.migrate_legacy_raids(session)
	EnemyAdventureRulesScript.normalize_all_commander_rosters(session)

static func _normalize_rebuild_pressure_request(value: Variant, current_day: int) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source: Dictionary = value
	var requested_day: int = max(0, int(source.get("requested_day", 0)))
	if requested_day <= 0:
		return {}
	if current_day > 0 and current_day - requested_day > REBUILD_PRESSURE_LAUNCH_WINDOW_DAYS:
		return {}
	var recent_exploration_target_ids := _normalize_string_array(
		source.get("recent_exploration_target_ids", [])
	)
	while recent_exploration_target_ids.size() > EnemyAdventureRulesScript.RAID_RECENT_EXPLORATION_TARGET_LIMIT:
		recent_exploration_target_ids.pop_front()
	return {
		"requested_day": requested_day,
		"origin_town_id": String(source.get("origin_town_id", "")),
		"commander_id": String(source.get("commander_id", "")),
		"reason": String(source.get("reason", "command_rebuild")),
		"recent_exploration_target_ids": recent_exploration_target_ids,
	}

static func normalize_optional_hero_task_state(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {
			"ok": false,
			"normalized_present": false,
			"invalid_reason": "hero_task_state_not_dictionary",
			"input_task_count": 0,
			"normalized_task_count": 0,
			"dropped_task_count": 0,
			"sanitized_field_count": 0,
			"observed_policy": "dropped_invalid_board",
		}
	var source: Dictionary = value
	var tasks_value = source.get("tasks", [])
	if not (tasks_value is Array):
		return {
			"ok": false,
			"normalized_present": false,
			"invalid_reason": "hero_task_state_tasks_not_array",
			"input_task_count": 0,
			"normalized_task_count": 0,
			"dropped_task_count": 0,
			"sanitized_field_count": max(0, source.keys().size()),
			"observed_policy": "dropped_invalid_board",
		}
	var normalized_tasks := []
	var dropped_count := 0
	var sanitized_count := _hero_task_state_board_sanitized_field_count(source)
	for task_value in tasks_value:
		var task_report := _normalize_hero_task_record(task_value)
		sanitized_count += int(task_report.get("sanitized_field_count", 0))
		if bool(task_report.get("ok", false)):
			normalized_tasks.append(task_report.get("task", {}))
		else:
			dropped_count += 1
	return {
		"ok": true,
		"normalized_present": true,
		"task_state": {
			"schema_version": clamp(max(1, int(source.get("schema_version", 1))), 1, 1),
			"planner_epoch": max(0, int(source.get("planner_epoch", 0))),
			"tasks": normalized_tasks,
		},
		"input_task_count": tasks_value.size(),
		"normalized_task_count": normalized_tasks.size(),
		"dropped_task_count": dropped_count,
		"sanitized_field_count": sanitized_count,
		"observed_policy": "preserved_and_normalized",
	}

## settle_rosters false: the caller normalizes the enemy states right after.
static func run_enemy_turn(session: SessionStateStoreScript.SessionData, settle_rosters: bool = true) -> Dictionary:
	var profile_enabled := _enemy_turn_profile_enabled()
	var profile := {
		"schema_id": "strategic_ai_enemy_turn_profile_v1",
		"day": int(session.day) if session != null else 0,
		"phases_ms": {},
		"factions": [],
	} if profile_enabled else {}
	AiHeroRulesScript.clear_shared_surfaces()
	var phase_started := _profile_timer(profile_enabled)
	DifficultyRulesScript.normalize_session(session)
	_profile_add_ms(profile, "difficulty_normalize_ms", phase_started)
	phase_started = _profile_timer(profile_enabled)
	normalize_enemy_states(session)
	_profile_add_ms(profile, "enemy_state_normalize_ms", phase_started)
	phase_started = _profile_timer(profile_enabled)
	var configs = _enemy_faction_configs_for_session(session)
	_profile_add_ms(profile, "config_lookup_ms", phase_started)
	if not (configs is Array) or configs.is_empty():
		return _enemy_turn_result(true, "", [], profile_enabled, profile)

	var states = session.overworld.get("enemy_states", [])
	var messages = []
	var events = []
	var should_apply_weekly_growth: bool = OverworldRulesScript.is_weekly_growth_day(session.day)

	for config in configs:
		if not (config is Dictionary):
			continue
		var faction_id = PlayerRules.controller_id(config)
		var state_index = _find_state_index(states, faction_id)
		if state_index < 0:
			continue
		var state = states[state_index]
		TurnPlayback.player_turn(session, config)
		# Computer players act through heroes and towns under the human's rules.
		var turn_result = AiHeroRulesScript.run_faction_turn(session, config, state, should_apply_weekly_growth, profile_enabled)
		state = _latest_enemy_state(session, faction_id, turn_result.get("state", state))
		states = session.overworld.get("enemy_states", states)
		state_index = _find_state_index(states, faction_id)
		if state_index < 0:
			continue
		if profile_enabled and turn_result.get("profile", {}) is Dictionary:
			profile["factions"].append(turn_result.get("profile", {}))
		var turn_messages = turn_result.get("messages", [])
		if turn_messages is Array:
			for message in turn_messages:
				if String(message) != "":
					messages.append(String(message))
		_append_event_records(events, turn_result.get("events", []))
		states[state_index] = state

	phase_started = _profile_timer(profile_enabled)
	session.overworld["enemy_states"] = states
	_profile_add_ms(profile, "state_writeback_ms", phase_started)
	if settle_rosters:
		phase_started = _profile_timer(profile_enabled)
		EnemyAdventureRulesScript.normalize_all_commander_rosters(session)
		_profile_add_ms(profile, "final_commander_roster_normalize_ms", phase_started)
	AiHeroRulesScript.clear_shared_surfaces()
	return _enemy_turn_result(true, " ".join(messages), events, profile_enabled, profile)

static func _enemy_turn_profile_enabled() -> bool:
	return OS.get_environment("HEROES_STRATEGIC_AI_PROFILE").strip_edges().to_lower() in ["1", "true", "yes", "on"]

static func _profile_timer(enabled: bool) -> int:
	return Time.get_ticks_usec() if enabled else 0

static func _profile_add_ms(profile: Dictionary, key: String, started_usec: int) -> void:
	if profile.is_empty() or key == "" or started_usec <= 0:
		return
	var phases: Dictionary = profile.get("phases_ms", {}) if profile.get("phases_ms", {}) is Dictionary else {}
	var elapsed_ms := int(round(float(max(0, Time.get_ticks_usec() - started_usec)) / 1000.0))
	phases[key] = int(phases.get(key, 0)) + elapsed_ms
	profile["phases_ms"] = phases

static func _enemy_turn_result(ok: bool, message: String, events: Array, profile_enabled: bool, profile: Dictionary) -> Dictionary:
	var result := {"ok": ok, "message": message, "events": events}
	if profile_enabled:
		result["profile"] = profile
	return result

static func _append_event_records(output: Array, events_value: Variant) -> void:
	if not (events_value is Array):
		return
	for event_value in events_value:
		if event_value is Dictionary and not event_value.is_empty():
			output.append(event_value)

static func describe_threats(session: SessionStateStoreScript.SessionData) -> String:
	normalize_enemy_states(session)
	var configs = _enemy_faction_configs_for_session(session)
	if not (configs is Array) or configs.is_empty():
		return "No hostile factions are active."

	var lines = []
	for config in configs:
		if not (config is Dictionary):
			continue
		# Only what a player could know: the rival's stance, its capital and the
		# heroes currently in sight.
		var faction_id = PlayerRules.controller_id(config)
		var state = _find_state(session.overworld.get("enemy_states", []), faction_id)
		var front_state := _faction_front_state(session, faction_id)
		var line_parts = [
			String(config.get("label", faction_id)),
			_public_posture_label(state, 0, PlayerRules.faction_id(session, faction_id)),
		]
		var strategy_summary = EnemyAdventureRulesScript.public_strategy_summary(config, faction_id)
		if strategy_summary != "":
			line_parts.append(strategy_summary)
		var capital_watch = _capital_watch_summary(_faction_capital_state(session, faction_id))
		if capital_watch != "":
			line_parts.append(capital_watch)
		var visible_heroes := _visible_raids_for_faction(session, faction_id)
		var hero_names = EnemyAdventureRulesScript.raid_commander_summaries(visible_heroes, 2)
		if not hero_names.is_empty():
			var sighting: String = "Heroes sighted %s" % ", ".join(hero_names)
			var hidden_count: int = max(0, visible_heroes.size() - hero_names.size())
			if hidden_count > 0:
				sighting += " (+%d more)" % hidden_count
			line_parts.append(sighting)
		var front_summary := String(front_state.get("summary", ""))
		if front_summary != "":
			line_parts.append(front_summary)
		lines.append(" | ".join(line_parts))

	return "\n".join(lines)

static func get_pressure(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	normalize_enemy_states(session)
	return int(_find_state(session.overworld.get("enemy_states", []), faction_id).get("pressure", 0))

static func active_raid_count(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	var count = 0
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not EnemyAdventureRulesScript.is_active_pressure_host(encounter, faction_id, resolved_encounters):
			continue
		count += 1
	return count

static func ai_town_build_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	selected_build: Dictionary
) -> Dictionary:
	if selected_build.is_empty():
		return {}
	var building_id := String(selected_build.get("building_id", ""))
	if building_id == "":
		return {}
	return EnemyAdventureRulesScript.build_ai_event_record(
		session,
		config,
		"ai_town_built",
		_town_actor(town),
		{
			"target_kind": "town_building",
			"target_placement_id": building_id,
			"target_label": String(selected_build.get("building_label", building_id)),
			"target_x": int(town.get("x", 0)),
			"target_y": int(town.get("y", 0)),
			"target_reason_codes": selected_build.get("reason_codes", []),
			"target_public_reason": String(selected_build.get("public_reason", "")),
			"target_public_importance": "medium",
			"target_debug_reason": String(selected_build.get("debug_reason", "")),
		},
		{
			"actor_label": _town_name(town),
			"summary": "%s builds %s (%s)." % [
				_town_name(town),
				String(selected_build.get("building_label", building_id)),
				String(selected_build.get("public_reason", "town pressure")),
			],
			"state_policy": "derived",
		}
	)

static func ai_town_recruit_event(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	town: Dictionary,
	selected_recruitment: Dictionary
) -> Dictionary:
	if selected_recruitment.is_empty():
		return {}
	var unit_id := String(selected_recruitment.get("unit_id", ""))
	if unit_id == "":
		return {}
	var destination: Dictionary = selected_recruitment.get("destination", {})
	var reason_codes: Array = _normalize_string_array(destination.get("reason_codes", []))
	if "town_recruitment" not in reason_codes:
		reason_codes.push_front("town_recruitment")
	return EnemyAdventureRulesScript.build_ai_event_record(
		session,
		config,
		"ai_town_recruited",
		_town_actor(town),
		{
			"target_kind": "unit",
			"target_placement_id": unit_id,
			"target_label": "%d %s" % [
				int(selected_recruitment.get("recruit_count", 0)),
				String(selected_recruitment.get("unit_label", unit_id)),
			],
			"target_x": int(town.get("x", 0)),
			"target_y": int(town.get("y", 0)),
			"target_reason_codes": reason_codes,
			"target_public_reason": String(destination.get("public_reason", "")),
			"target_public_importance": "medium",
			"target_debug_reason": String(destination.get("debug_reason", "")),
		},
		{
			"actor_label": _town_name(town),
			"summary": "%s recruits %d %s for %s." % [
				_town_name(town),
				int(selected_recruitment.get("recruit_count", 0)),
				String(selected_recruitment.get("unit_label", unit_id)),
				String(destination.get("public_reason", "front pressure")),
			],
			"state_policy": "derived",
		}
	)

static func _town_actor(town: Dictionary) -> Dictionary:
	return {
		"placement_id": String(town.get("placement_id", "")),
		"name": _town_name(town),
		"x": int(town.get("x", 0)),
		"y": int(town.get("y", 0)),
		"level": LevelRules.level_of(town),
	}

static func _visible_raids_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Array:
	var visible := []
	var resolved_encounters = session.overworld.get("resolved_encounters", [])
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if PlayerRules.raid_controller_id(encounter) != faction_id:
			continue
		if resolved_encounters is Array and String(encounter.get("placement_id", "")) in resolved_encounters:
			continue
		if not EnemyAdventureRulesScript._raid_is_public(session, encounter):
			continue
		visible.append(encounter)
	return visible

static func _faction_front_state(
	session: SessionStateStoreScript.SessionData,
	faction_id: String
) -> Dictionary:
	var retake_labels: Array = []
	var stabilizing_labels: Array = []
	var pressure_bonus := 0
	var threshold_reduction := 0
	var garrison_bonus := 0
	var build_bonus := 0
	var retake_count := 0
	var stabilizing_count := 0
	var top_front_priority := 0
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		var front: Dictionary = OverworldRulesScript.town_front_state(session, town)
		if not bool(front.get("active", false)) or PlayerRules.controller_id(front) != faction_id:
			continue
		var compact_summary := String(front.get("compact_summary", _town_name(town)))
		top_front_priority = max(top_front_priority, int(front.get("priority_bonus", 0)))
		match String(front.get("mode", "")):
			"retake":
				retake_count += 1
				pressure_bonus += int(front.get("pressure_bonus", 0))
				threshold_reduction = max(threshold_reduction, int(front.get("threshold_reduction", 0)))
				if compact_summary != "" and compact_summary not in retake_labels:
					retake_labels.append(compact_summary)
			"stabilizing":
				stabilizing_count += 1
				garrison_bonus += int(front.get("garrison_bonus", 0))
				build_bonus += int(front.get("build_bonus", 0))
				if compact_summary != "" and compact_summary not in stabilizing_labels:
					stabilizing_labels.append(compact_summary)
	var parts := []
	if not retake_labels.is_empty():
		parts.append(
			"Retake fronts %s" % ", ".join(retake_labels.slice(0, min(2, retake_labels.size())))
		)
	if not stabilizing_labels.is_empty():
		parts.append(
			"Stabilizing %s" % ", ".join(stabilizing_labels.slice(0, min(2, stabilizing_labels.size())))
		)
	return {
		"retake_count": retake_count,
		"stabilizing_count": stabilizing_count,
		"pressure_bonus": clampi(pressure_bonus, 0, 4),
		"threshold_reduction": clampi(threshold_reduction, 0, 2),
		"garrison_bonus": clampi(garrison_bonus, 0, 180),
		"build_bonus": clampi(build_bonus, 0, 160),
		"top_front_priority": top_front_priority,
		"summary": " | ".join(parts),
	}

static func _latest_enemy_state(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	fallback: Dictionary
) -> Dictionary:
	if session == null or faction_id == "":
		return fallback
	var latest := _find_state(session.overworld.get("enemy_states", []), faction_id)
	if latest.is_empty() or fallback.is_empty():
		return latest if not latest.is_empty() else fallback
	var merged := fallback.duplicate(true)
	# Commander and memory helpers persist these fields directly while the
	# faction turn returns treasury and posture in its local state.
	for runtime_key in EnemyAdventureRulesScript.SESSION_OWNED_ENEMY_STATE_KEYS:
		if latest.has(runtime_key):
			merged[runtime_key] = latest.get(runtime_key)
		else:
			merged.erase(runtime_key)
	return merged

static func _apply_weekly_musters(
	session: SessionStateStoreScript.SessionData,
	town_entries: Array,
	towns: Array,
	faction_id: String,
	config: Dictionary
) -> String:
	var musters = []
	for entry in town_entries:
		var town = entry.get("town", {})
		var growth: Dictionary = OverworldRulesScript.town_weekly_growth(town, session)
		town["available_recruits"] = _merge_recruits(town.get("available_recruits", {}), growth)
		towns[int(entry.get("index", -1))] = town
		if not growth.is_empty():
			musters.append("%s (%s)" % [_town_name(town), _describe_recruit_delta(growth)])
	if session != null:
		musters.append_array(OverworldRulesScript.apply_controlled_resource_site_musters(session, faction_id))
	if musters.is_empty():
		return ""
	return "%s musters fresh levies at %s." % [
		String(config.get("label", faction_id)),
		"; ".join(musters),
	]

static func _enemy_town_accessible_spell_ids(town: Dictionary) -> Array:
	if TownRulesScript == null:
		return []
	return TownRulesScript.accessible_spell_ids(town)

static func _public_posture_label(state: Dictionary, raid_threshold: int, faction_id: String) -> String:
	match _normalize_posture(state.get("posture", "probing")):
		"reorganizing":
			match faction_id:
				"faction_embercourt":
					return "Road captains are reorganizing after the last clash"
				"faction_mireclaw":
					return "Wounded warbands are slipping back into the reeds to regroup"
				"faction_sunvault":
					return "Relay commanders are recalibrating after the last exchange"
				"faction_thornwake":
					return "Graftwardens are regrowing lanes after the last clash"
				"faction_brasshollow":
					return "Foundry officers are cooling engines before the next contract push"
				"faction_veilmourn":
					return "Black-sail crews are vanishing into fog to reset their routes"
			return "Hostile commanders are regrouping before the next push"
		"fortifying":
			match faction_id:
				"faction_embercourt":
					return "Beacon towns are drawing disciplined levies onto the walls"
				"faction_mireclaw":
					return "Stockades are beating the drums for a local stand"
				"faction_sunvault":
					return "Relay keeps are locking into prepared firing lines"
				"faction_thornwake":
					return "Root towns are thickening bramble roads around the walls"
				"faction_brasshollow":
					return "Foundries are plating the wall engines for a hard stand"
				"faction_veilmourn":
					return "Bell harbors are masking their docks behind fresh fog"
			return "Border towns are pulling fresh troops onto the walls"
		"raiding":
			match faction_id:
				"faction_embercourt":
					return "Charter columns are pushing measured strikes down the lanes"
				"faction_mireclaw":
					return "Warbands are spilling forward in staggered packs"
				"faction_sunvault":
					return "Compact sorties are testing the frontier behind relay screens"
				"faction_thornwake":
					return "Root pilgrims are spreading bramble tolls onto the frontier"
				"faction_brasshollow":
					return "Contract columns are rolling engines toward production sites"
				"faction_veilmourn":
					return "Black-sail crews are slipping through fog lanes toward weak backs"
			return "Enemy heroes are driving into the frontier"
		"massing":
			if int(state.get("pressure", 0)) >= raid_threshold * 2:
				match faction_id:
					"faction_embercourt":
						return "A heavier charter assault is assembling behind the line"
					"faction_mireclaw":
						return "A deeper mire surge is gathering in the reeds"
					"faction_sunvault":
						return "Another calibrated battery strike is aligning behind the front"
					"faction_thornwake":
						return "A rooted nursery front is spreading behind the roads"
					"faction_brasshollow":
						return "A heavy foundry assault is staging behind the railhead"
					"faction_veilmourn":
						return "A deeper fog wake is gathering beyond the charted routes"
				return "A heavier strike is gathering behind the lines"
			match faction_id:
				"faction_embercourt":
					return "Quartermasters are assembling another road-bound column"
				"faction_mireclaw":
					return "Fresh cutters are massing for another sudden push"
				"faction_sunvault":
					return "Arrays are lining up for another focused push"
				"faction_thornwake":
					return "Graft hosts are massing around newly rooted roads"
				"faction_brasshollow":
					return "Boiler crews are massing for another siege-stage push"
				"faction_veilmourn":
					return "Mist crews are massing around a hidden approach"
			return "War bands are massing for another strike"
		"collapsed":
			return "The hostile empire has lost its strongholds"
		"attacking":
			return "Enemy heroes are on the attack"
		"expanding":
			return "Enemy heroes are claiming the countryside"
		"building":
			return "Enemy towns are building up their strength"
		_:
			match faction_id:
				"faction_embercourt":
					return "Scouts report charter patrols measuring the line"
				"faction_mireclaw":
					return "Scouts report mire runners probing for soft targets"
				"faction_sunvault":
					return "Scouts report relay pickets calibrating the approaches"
				"faction_thornwake":
					return "Scouts report root pilgrims seeding the approaches"
				"faction_brasshollow":
					return "Scouts report ore contracts and pressure gauges moving forward"
				"faction_veilmourn":
					return "Scouts report bell wakes sounding from unseen routes"
			return "Scouts report patrols probing for openings"

static func _enemy_faction_configs_for_session(session: SessionStateStoreScript.SessionData) -> Array:
	if session == null:
		return []
	var players: Array = session.overworld.get("players", [])
	if not players.is_empty():
		return _enemy_faction_configs_with_runtime_defaults(session, PlayerRules.enemy_configs(players))
	var scenario = ContentService.get_scenario_readonly(session.scenario_id)
	var configs = scenario.get("enemy_factions", [])
	if configs is Array and not configs.is_empty():
		var valid_configs := _valid_enemy_faction_configs(configs)
		if not valid_configs.is_empty():
			return _enemy_faction_configs_with_runtime_defaults(session, valid_configs)
	var runtime_record: Dictionary = session.overworld.get("native_random_map_runtime_scenario_record", {}) if session.overworld.get("native_random_map_runtime_scenario_record", {}) is Dictionary else {}
	configs = runtime_record.get("enemy_factions", [])
	if configs is Array:
		var valid_runtime_configs := _valid_enemy_faction_configs(configs)
		if not valid_runtime_configs.is_empty():
			return _enemy_faction_configs_with_runtime_defaults(session, valid_runtime_configs)
	var fallback_configs := []
	var seen := {}
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if String(town.get("owner", "neutral")) != "enemy":
			continue
		var faction_id := _town_controller_faction_id(town)
		if faction_id == "" or bool(seen.get(faction_id, false)):
			continue
		var faction := ContentService.get_faction(faction_id)
		if faction.is_empty():
			continue
		seen[faction_id] = true
		fallback_configs.append({
			"faction_id": faction_id,
			"label": String(faction.get("name", faction_id)),
			"generated_package_town_config": true,
		})
	return _enemy_faction_configs_with_runtime_defaults(session, fallback_configs)

static func _valid_enemy_faction_configs(configs: Array) -> Array:
	var result := []
	for config_value in configs:
		if not (config_value is Dictionary):
			continue
		var config: Dictionary = config_value
		if ContentService.get_faction(String(config.get("faction_id", ""))).is_empty():
			continue
		result.append(config.duplicate(true))
	return result

static func _enemy_faction_configs_with_runtime_defaults(session: SessionStateStoreScript.SessionData, configs: Array) -> Array:
	var result := []
	for config_value in configs:
		if not (config_value is Dictionary):
			continue
		result.append(_enemy_faction_config_with_runtime_defaults(session, config_value))
	return result

static func _enemy_faction_config_with_runtime_defaults(session: SessionStateStoreScript.SessionData, config: Dictionary) -> Dictionary:
	var normalized := config.duplicate(true)
	var faction_id := String(normalized.get("faction_id", ""))
	if faction_id == "":
		return normalized
	var faction := ContentService.get_faction(faction_id)
	if String(normalized.get("label", "")) == "":
		normalized["label"] = String(faction.get("name", faction_id))
	if int(normalized.get("pressure_per_day", 0)) <= 0:
		normalized["pressure_per_day"] = 2
	if int(normalized.get("pressure_per_enemy_town", 0)) <= 0:
		normalized["pressure_per_enemy_town"] = 1
	if int(normalized.get("raid_threshold", 0)) <= 0:
		normalized["raid_threshold"] = 5
	if int(normalized.get("max_active_raids", 0)) <= 0:
		normalized["max_active_raids"] = 2
	if int(normalized.get("raid_pillage_delay", 0)) <= 0:
		normalized["raid_pillage_delay"] = 1
	if not (normalized.get("raid_pillage", {}) is Dictionary) or normalized.get("raid_pillage", {}).is_empty():
		normalized["raid_pillage"] = {"gold": 150}
	if not (normalized.get("raid_encounter_ids", []) is Array) or normalized.get("raid_encounter_ids", []).is_empty():
		normalized["raid_encounter_ids"] = _default_raid_encounter_ids_for_faction(faction_id)
	if not (normalized.get("spawn_points", []) is Array) or normalized.get("spawn_points", []).is_empty():
		normalized["spawn_points"] = _default_spawn_points_for_faction(session, PlayerRules.controller_id(normalized))
	if not (normalized.get("priority_target_placement_ids", []) is Array):
		normalized["priority_target_placement_ids"] = []
	if int(normalized.get("priority_target_bonus", 0)) <= 0:
		normalized["priority_target_bonus"] = 80
	if not bool(normalized.get("generated_package_town_config", false)) and _config_was_runtime_defaulted(config, normalized):
		normalized["generated_package_town_config"] = bool(session != null and bool(session.flags.get("generated_random_map", false)))
	return normalized

static func _config_was_runtime_defaulted(source: Dictionary, normalized: Dictionary) -> bool:
	for key in ["pressure_per_day", "pressure_per_enemy_town", "raid_threshold", "max_active_raids", "raid_pillage_delay", "raid_pillage", "raid_encounter_ids", "spawn_points"]:
		if not source.has(key) and normalized.has(key):
			return true
	return false

static func _default_raid_encounter_ids_for_faction(faction_id: String) -> Array:
	match faction_id:
		"faction_mireclaw":
			return ["encounter_mire_raid", "encounter_blackbranch_reavers"]
		"faction_sunvault":
			return ["encounter_aurora_battery", "encounter_daybreak_matrix"]
		"faction_thornwake":
			return ["encounter_graftroot_wardens"]
		"faction_brasshollow":
			return ["encounter_orevein_exactors"]
		"faction_veilmourn":
			return ["encounter_bellwake_privateers"]
		_:
			return ["encounter_ford_reavers", "encounter_mire_raid"]

static func _default_spawn_points_for_faction(session: SessionStateStoreScript.SessionData, faction_id: String) -> Array:
	var points := []
	if session == null:
		return points
	for entry in _owned_town_entries(session, faction_id):
		if not (entry is Dictionary):
			continue
		var town: Dictionary = entry.get("town", {}) if entry.get("town", {}) is Dictionary else {}
		if town.is_empty():
			continue
		points.append(LevelRules.town_entrance(town))
	return points

static func _owned_town_count(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	return _owned_town_entries(session, faction_id).size()

static func _owned_town_entries(session: SessionStateStoreScript.SessionData, faction_id: String) -> Array:
	var entries = []
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_controller_faction_id(town) != faction_id:
			continue
		entries.append({"index": index, "town": town})
	return entries

static func _faction_capital_state(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	return _faction_capital_state_from_towns(session, session.overworld.get("towns", []), faction_id)

static func _faction_capital_state_from_towns(
	session: SessionStateStoreScript.SessionData,
	towns: Array,
	faction_id: String
) -> Dictionary:
	var state = {
		"capital_count": 0,
		"stronghold_count": 0,
		"anchor_labels": [],
		"active_project_labels": [],
		"dormant_project_labels": [],
		"pressure_bonus": 0,
		"defense_bonus": 0,
		"raid_threshold_reduction": 0,
		"max_active_raids_bonus": 0,
		"active_projects": 0,
		"support_gap": 0,
		"recovery_pressure": 0,
	}
	for town in towns:
		if not (town is Dictionary) or String(town.get("owner", "neutral")) != "enemy":
			continue
		if _town_controller_faction_id(town) != faction_id:
			continue
		var role: String = OverworldRulesScript.town_strategic_role(town)
		var town_name = _town_name(town)
		match role:
			"capital":
				state["capital_count"] = int(state.get("capital_count", 0)) + 1
				state["anchor_labels"].append(town_name)
			"stronghold":
				state["stronghold_count"] = int(state.get("stronghold_count", 0)) + 1
				state["anchor_labels"].append(town_name)
		var capital_project: Dictionary = OverworldRulesScript.town_capital_project_state(town, session)
		if int(capital_project.get("active", 0)) > 0:
			state["active_projects"] = int(state.get("active_projects", 0)) + int(capital_project.get("active", 0))
			state["active_project_labels"].append(town_name)
			state["pressure_bonus"] = int(state.get("pressure_bonus", 0)) + int(capital_project.get("pressure_bonus", 0))
			state["defense_bonus"] = int(state.get("defense_bonus", 0)) + int(capital_project.get("defense_bonus", 0))
			state["raid_threshold_reduction"] = int(state.get("raid_threshold_reduction", 0)) + int(capital_project.get("raid_threshold_reduction", 0))
			state["max_active_raids_bonus"] = int(state.get("max_active_raids_bonus", 0)) + int(capital_project.get("max_active_raids_bonus", 0))
			state["support_gap"] = int(state.get("support_gap", 0)) + int(capital_project.get("support_gap", 0))
		elif int(capital_project.get("total", 0)) > 0:
			state["dormant_project_labels"].append(town_name)
		state["recovery_pressure"] = int(state.get("recovery_pressure", 0)) + int(OverworldRulesScript.town_recovery_state(session, town).get("pressure", 0))
	return state

static func _capital_watch_summary(capital_state: Dictionary) -> String:
	var active_labels = capital_state.get("active_project_labels", [])
	if active_labels is Array and not active_labels.is_empty():
		var parts = ["Capital watch: %s online" % ", ".join(active_labels)]
		if int(capital_state.get("support_gap", 0)) > 0:
			parts.append("logistics gaps %d" % int(capital_state.get("support_gap", 0)))
		if int(capital_state.get("recovery_pressure", 0)) > 0:
			parts.append("recovery %d" % int(capital_state.get("recovery_pressure", 0)))
		return ", ".join(parts)
	var dormant_labels = capital_state.get("dormant_project_labels", [])
	if dormant_labels is Array and not dormant_labels.is_empty():
		return "Capital watch: %s still anchors the front" % ", ".join(dormant_labels)
	var anchor_labels = capital_state.get("anchor_labels", [])
	if anchor_labels is Array and not anchor_labels.is_empty():
		return "Anchor watch: %s remain the backbone of the front" % ", ".join(anchor_labels)
	return ""

static func _raid_threshold_for_strategy(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	launch_policy_context: Dictionary = {}
) -> int:
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	var base_threshold = DifficultyRulesScript.adjust_raid_threshold(session, max(1, int(config.get("raid_threshold", 1))))
	var threshold_scale = clamp(
		EnemyAdventureRulesScript.strategy_scalar(strategy, "raid", "threshold_scale", 1.0),
		0.65,
		1.5
	)
	var threshold = max(1, int(round(float(base_threshold) * threshold_scale)))
	var capital_state := _launch_policy_capital_state(session, faction_id, launch_policy_context)
	threshold -= int(capital_state.get("raid_threshold_reduction", 0))
	threshold -= int(_launch_policy_front_state(session, faction_id, launch_policy_context).get("threshold_reduction", 0))
	if session.day >= 5 and int(capital_state.get("active_projects", 0)) > 0:
		threshold -= 1
	return max(1, threshold)

static func _max_active_raids_for_strategy(
	session: SessionStateStoreScript.SessionData,
	config: Dictionary,
	faction_id: String,
	launch_policy_context: Dictionary = {}
) -> int:
	var strategy = EnemyAdventureRulesScript.enemy_strategy(config, faction_id)
	var capital_state := _launch_policy_capital_state(session, faction_id, launch_policy_context)
	return max(
		1,
		int(config.get("max_active_raids", 1))
		+ EnemyAdventureRulesScript.strategy_int(strategy, "raid", "max_active_bonus", 0)
		+ int(capital_state.get("max_active_raids_bonus", 0))
	)

static func _launch_policy_capital_state(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	launch_policy_context: Dictionary = {}
) -> Dictionary:
	var cached = launch_policy_context.get("capital_state", null)
	if cached is Dictionary:
		return cached
	var loaded := _faction_capital_state(session, faction_id)
	launch_policy_context["capital_state"] = loaded
	return loaded

static func _launch_policy_front_state(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	launch_policy_context: Dictionary = {}
) -> Dictionary:
	var cached = launch_policy_context.get("front_state", null)
	if cached is Dictionary:
		return cached
	var loaded := _faction_front_state(session, faction_id)
	launch_policy_context["front_state"] = loaded
	return loaded

static func _enemy_recruit_cost(town: Dictionary, unit_id: String) -> Dictionary:
	var unit = ContentService.get_unit(unit_id)
	return _apply_discount(unit.get("cost", {}), _recruitment_discount_percent(town, unit_id))

static func _recruitment_discount_percent(town: Dictionary, unit_id: String) -> int:
	var town_template = ContentService.get_town(String(town.get("town_id", "")))
	var total_discount = _discount_from_profile(town_template.get("recruitment", {}), unit_id)
	total_discount += _discount_from_profile(
		ContentService.get_faction(String(town_template.get("faction_id", ""))).get("recruitment", {}),
		unit_id
	)
	for building_id in _normalized_built_buildings(town):
		var recruit_discount = ContentService.get_building(String(building_id)).get("recruitment_discount_percent", {})
		if recruit_discount is Dictionary:
			total_discount += int(recruit_discount.get(unit_id, 0))
	return clamp(total_discount, 0, 75)

static func _discount_from_profile(profile: Variant, unit_id: String) -> int:
	if not (profile is Dictionary):
		return 0
	var discounts = profile.get("cost_discount_percent", {})
	if not (discounts is Dictionary):
		return 0
	return max(0, int(discounts.get(unit_id, 0)))

static func _building_growth_payload(building_id: String) -> Dictionary:
	var payload = {}
	var building = ContentService.get_building(building_id)
	if int(building.get("development_version", 0)) == 1:
		return TownDevelopment.construction_growth(building)
	var unlock_unit_id = String(building.get("unlock_unit_id", ""))
	if unlock_unit_id != "":
		payload[unlock_unit_id] = _scenario_factory()._unit_growth(unlock_unit_id)
	var growth_bonus = building.get("growth_bonus", {})
	if growth_bonus is Dictionary:
		for unit_id in growth_bonus.keys():
			payload[String(unit_id)] = int(payload.get(String(unit_id), 0)) + int(growth_bonus[unit_id])
	return payload

static func _merge_recruits(base: Variant, delta: Variant) -> Dictionary:
	var merged = {}
	if base is Dictionary:
		for unit_id in base.keys():
			merged[String(unit_id)] = max(0, int(base[unit_id]))
	if delta is Dictionary:
		for unit_id in delta.keys():
			merged[String(unit_id)] = int(merged.get(String(unit_id), 0)) + max(0, int(delta[unit_id]))
	return merged

static func _consume_recruits(base: Variant, unit_id: String, amount: int) -> Dictionary:
	var remaining = {}
	if base is Dictionary:
		for existing_unit_id in base.keys():
			remaining[String(existing_unit_id)] = max(0, int(base[existing_unit_id]))
	remaining[unit_id] = max(0, int(remaining.get(unit_id, 0)) - max(0, amount))
	return remaining

static func _spend_from_pool(pool: Dictionary, cost: Variant) -> void:
	if not (cost is Dictionary):
		return
	for key in cost.keys():
		var resource_key = String(key)
		pool[resource_key] = max(0, int(pool.get(resource_key, 0)) - max(0, int(cost[key])))

static func _scale_resource_pool(cost: Variant, multiplier: int) -> Dictionary:
	var scaled = {}
	if not (cost is Dictionary):
		return scaled
	for key in cost.keys():
		scaled[String(key)] = max(0, int(cost[key])) * max(0, multiplier)
	return scaled

static func _normalize_resource_pool(value: Variant) -> Dictionary:
	var normalized = _blank_resource_pool()
	if value is Dictionary:
		for key in value.keys():
			normalized[String(key)] = max(0, int(value[key]))
	return normalized

static func _blank_resource_pool() -> Dictionary:
	var resources = {}
	for resource_key in TRACKED_RESOURCES:
		resources[resource_key] = 0
	return resources

static func _apply_discount(cost: Variant, discount_percent: int) -> Dictionary:
	var discounted = {}
	var clamped_discount = clamp(discount_percent, 0, 75)
	if cost is Dictionary:
		for key in cost.keys():
			var resource_key = String(key)
			var base_amount = max(0, int(cost[key]))
			discounted[resource_key] = int(ceili(float(base_amount * (100 - clamped_discount)) / 100.0))
	return discounted

static func _normalize_posture(value: Variant) -> String:
	var posture = String(value)
	if posture in ["probing", "massing", "raiding", "fortifying", "reorganizing", "collapsed", "attacking", "expanding", "building"]:
		return posture
	return "probing"

static func _normalize_hero_task_record(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {"ok": false, "invalid_reason": "task_not_dictionary", "sanitized_field_count": 0}
	var task: Dictionary = value
	var required_strings := [
		"task_id",
		"owner_faction_id",
		"actor_id",
		"task_class",
		"target_id",
	]
	for required_key in required_strings:
		if String(task.get(String(required_key), "")) == "":
			return {
				"ok": false,
				"invalid_reason": "missing_%s" % String(required_key),
				"sanitized_field_count": _hero_task_record_sanitized_field_count(task),
			}
	var task_class := _normalize_hero_task_class(task.get("task_class", ""))
	var task_status := _normalize_hero_task_status(task.get("task_status", "planned"))
	var target_kind := _normalize_hero_task_target_kind(task.get("target_kind", ""))
	var validation := _normalize_hero_task_validation_code(task.get("last_validation", "valid"))
	if task_class == "" or task_status == "" or target_kind == "" or validation == "":
		return {
			"ok": false,
			"invalid_reason": "unsupported_task_enum",
			"sanitized_field_count": _hero_task_record_sanitized_field_count(task),
		}
	var normalized := {
		"task_id": String(task.get("task_id", "")),
		"owner_faction_id": String(task.get("owner_faction_id", "")),
		"actor_kind": _normalize_hero_task_actor_kind(task.get("actor_kind", "commander_roster")),
		"actor_id": String(task.get("actor_id", "")),
		"source_kind": _normalize_hero_task_source_kind(task.get("source_kind", "commander_role_adapter")),
		"source_id": String(task.get("source_id", "")),
		"task_class": task_class,
		"task_status": task_status,
		"target_kind": target_kind,
		"target_id": String(task.get("target_id", "")),
		"front_id": String(task.get("front_id", "")),
		"origin_kind": _normalize_hero_task_origin_kind(task.get("origin_kind", "town")),
		"origin_id": String(task.get("origin_id", "")),
		"priority_reason_codes": _normalize_string_array(task.get("priority_reason_codes", [])),
		"assigned_day": max(0, int(task.get("assigned_day", 0))),
		"expires_day": max(0, int(task.get("expires_day", 0))),
		"continuity_policy": _normalize_hero_task_continuity_policy(task.get("continuity_policy", "persist_until_invalid")),
		"route_policy": _normalize_hero_task_route_policy(task.get("route_policy", "derive_route_on_turn")),
		"last_validation": validation,
	}
	if String(task.get("owner_player_id", "")) != "":
		normalized["owner_player_id"] = String(task.owner_player_id)
	if task.has("invalidated_by_task_id"):
		normalized["invalidated_by_task_id"] = String(task.get("invalidated_by_task_id", ""))
	if task.get("reservation", {}) is Dictionary:
		normalized["reservation"] = _normalize_hero_task_reservation(task.get("reservation", {}))
	return {
		"ok": true,
		"task": normalized,
		"sanitized_field_count": _hero_task_record_sanitized_field_count(task),
	}

static func _hero_task_state_board_sanitized_field_count(board: Dictionary) -> int:
	var allowed := {"schema_version": true, "planner_epoch": true, "tasks": true}
	var sanitized := 0
	for key in board.keys():
		if not allowed.has(String(key)):
			sanitized += 1
	return sanitized

static func _hero_task_record_sanitized_field_count(task: Dictionary) -> int:
	var allowed := {
		"task_id": true,
		"owner_faction_id": true,
		"owner_player_id": true,
		"actor_kind": true,
		"actor_id": true,
		"source_kind": true,
		"source_id": true,
		"task_class": true,
		"task_status": true,
		"target_kind": true,
		"target_id": true,
		"front_id": true,
		"origin_kind": true,
		"origin_id": true,
		"priority_reason_codes": true,
		"assigned_day": true,
		"expires_day": true,
		"continuity_policy": true,
		"route_policy": true,
		"last_validation": true,
		"reservation": true,
		"invalidated_by_task_id": true,
	}
	var sanitized := 0
	for key in task.keys():
		if not allowed.has(String(key)):
			sanitized += 1
	return sanitized

static func _normalize_hero_task_class(value: Variant) -> String:
	var task_class := String(value)
	if task_class in ["raid_town", "retake_site", "contest_site", "stabilize_front", "defend_front", "scout_frontier", "recover_commander", "rebuild_host", "reserve"]:
		return task_class
	return ""

static func _normalize_hero_task_status(value: Variant) -> String:
	var task_status := String(value)
	if task_status in ["candidate", "planned", "reserved", "active", "suspended", "blocked", "completed", "failed", "cancelled", "invalid"]:
		return task_status
	return ""

static func _normalize_hero_task_target_kind(value: Variant) -> String:
	var target_kind := String(value)
	if target_kind in ["resource", "town", "artifact", "encounter", "hero", "regroup", "commander", "front"]:
		return target_kind
	if target_kind == "explore":
		return target_kind
	return ""

static func _normalize_hero_task_actor_kind(value: Variant) -> String:
	var actor_kind := String(value)
	return actor_kind if actor_kind in ["commander_roster", "active_encounter", "ai_hero"] else "commander_roster"

static func _normalize_hero_task_source_kind(value: Variant) -> String:
	var source_kind := String(value)
	return source_kind if source_kind in ["commander_role_adapter", "saved_task_state"] else "commander_role_adapter"

static func _normalize_hero_task_origin_kind(value: Variant) -> String:
	var origin_kind := String(value)
	return origin_kind if origin_kind in ["town", "front", "encounter"] else "town"

static func _normalize_hero_task_continuity_policy(value: Variant) -> String:
	var policy := String(value)
	return policy if policy in ["persist_until_invalid", "expire_on_day", "derive_each_turn"] else "persist_until_invalid"

static func _normalize_hero_task_route_policy(value: Variant) -> String:
	var policy := String(value)
	return policy if policy in ["derive_route_on_turn", "hold_position", "route_deferred"] else "derive_route_on_turn"

static func _normalize_hero_task_validation_code(value: Variant) -> String:
	var code := String(value)
	if code in [
		"valid",
		"invalid_target_missing",
		"invalid_target_resolved",
		"invalid_controller_changed",
		"invalid_target_reserved",
		"invalid_front_quiet",
		"invalid_actor_missing",
		"invalid_actor_recovering",
		"invalid_actor_rebuilding",
		"invalid_actor_active_elsewhere",
		"invalid_actor_defeated",
		"invalid_battle_defeat",
		"invalid_battle_withdrawal",
		"invalid_origin_missing",
		"invalid_origin_controller_changed",
		"invalid_route_unreachable",
		"invalid_approach_unavailable",
		"invalid_task_expired",
		"battle_stalemate",
		"cancelled_by_retask",
		"invalid_script_lock",
		"invalid_scenario_complete",
	]:
		return code
	return ""

static func _normalize_hero_task_reservation(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {"reservation_status": "none", "reservation_scope": "none", "reservation_key": ""}
	var reservation: Dictionary = value
	var status := String(reservation.get("reservation_status", "none"))
	if status not in ["none", "primary", "shared", "released", "rejected_duplicate"]:
		status = "none"
	var scope := String(reservation.get("reservation_scope", "none"))
	if scope not in ["none", "exclusive_target", "shared_front"]:
		scope = "none"
	return {
		"reservation_status": status,
		"reservation_scope": scope,
		"reservation_key": String(reservation.get("reservation_key", "")),
	}

static func _normalize_string_array(value: Variant) -> Array:
	var normalized = []
	if not (value is Array):
		return normalized
	for entry in value:
		var item = String(entry)
		if item != "" and item not in normalized:
			normalized.append(item)
	return normalized

static func _normalized_built_buildings(town: Dictionary) -> Array:
	if TownDevelopment.is_current(town): return TownDevelopment.active_buildings(town)
	var normalized = []
	var town_template = ContentService.get_town(String(town.get("town_id", "")))
	for building_id_value in town_template.get("starting_building_ids", []):
		_append_building_with_requirements(normalized, String(building_id_value))
	for building_id_value in town.get("built_buildings", []):
		_append_building_with_requirements(normalized, String(building_id_value))
	return normalized

static func _append_building_with_requirements(target: Array, building_id: String, trail: Array = []) -> void:
	if building_id == "" or building_id in target or building_id in trail:
		return
	var next_trail = trail.duplicate(true)
	next_trail.append(building_id)
	var building = ContentService.get_building(building_id)
	var upgrade_from = String(building.get("upgrade_from", ""))
	if upgrade_from != "":
		_append_building_with_requirements(target, upgrade_from, next_trail)
	for requirement_value in building.get("requires", []):
		_append_building_with_requirements(target, String(requirement_value), next_trail)
	target.append(building_id)

static func _describe_recruit_delta(delta: Variant) -> String:
	if not (delta is Dictionary) or delta.is_empty():
		return ""
	var parts = []
	var unit_ids = []
	for unit_id_value in delta.keys():
		unit_ids.append(String(unit_id_value))
	unit_ids.sort()
	for unit_id in unit_ids:
		var amount = int(delta.get(unit_id, 0))
		if amount <= 0:
			continue
		var unit = ContentService.get_unit(unit_id)
		parts.append("+%d %s" % [amount, String(unit.get("name", unit_id))])
	return ", ".join(parts)

static func _find_state(states: Variant, faction_id: String) -> Dictionary:
	if states is Array:
		for state in states:
			if state is Dictionary and PlayerRules.controller_id(state) == faction_id:
				return state
	return {}

static func _find_state_index(states: Variant, faction_id: String) -> int:
	if states is Array:
		for index in range(states.size()):
			var state = states[index]
			if state is Dictionary and PlayerRules.controller_id(state) == faction_id:
				return index
	return -1

static func _town_name(town_state: Dictionary) -> String:
	var town = ContentService.get_town(String(town_state.get("town_id", "")))
	return String(town.get("name", town_state.get("town_id", "Town")))

static func _town_controller_faction_id(town_state: Dictionary) -> String:
	return PlayerRules.town_controller_id(town_state)
