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
const DayEngine = preload("res://scripts/core/DayEngine.gd")
const TurnEngine = preload("res://scripts/core/TurnEngine.gd")
static var _day_engine_mode: int = DayEngine.mode
# Computer-player state AiHeroRules keeps between days.
const AI_PLAYER_STATE_KEYS := ["ai_start_hero_granted", "ai_opening_granted", "ai_tavern", "ai_hero_counter", "ai_explored", "ai_boat_wanted_day", "ai_sightings", "ai_weight_set"]
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
# rebuild_pressure_request comes only from older saves (nothing writes it any
# more); it lapses after this many days.
const REBUILD_PRESSURE_LAUNCH_WINDOW_DAYS := 5

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
	if _day_engine_mode == DayEngine.GDSCRIPT:
		normalize_enemy_states__gd(session)
	elif _day_engine_mode == DayEngine.NATIVE:
		DayEngine.native_writing(&"EnemyTurnRules.normalize_enemy_states", [session])
		if DayEngine.not_ported():
			normalize_enemy_states__gd(session)
	else:
		var before := DayEngine.before_writing([session])
		normalize_enemy_states__gd(session)
		DayEngine.check_writing(&"EnemyTurnRules.normalize_enemy_states", before, [session], null)

static func normalize_enemy_states__gd(session: SessionStateStoreScript.SessionData) -> void:
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
	return TurnEngine.native_writing(&"EnemyTurnRules.normalize_optional_hero_task_state", [value])

## settle_rosters false: the caller normalizes the enemy states right after.
static func run_enemy_turn(session: SessionStateStoreScript.SessionData, settle_rosters: bool = true) -> Dictionary:
	var result: Variant = TurnEngine.native_writing(&"EnemyTurnRules.run_enemy_turn", [session, settle_rosters])
	return result if result is Dictionary else {"ok": false, "message": "", "events": []}

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
	return TurnEngine.native_writing(&"EnemyTurnRules.get_pressure", [session, faction_id])

static func active_raid_count(session: SessionStateStoreScript.SessionData, faction_id: String) -> int:
	return TurnEngine.native_writing(&"EnemyTurnRules.active_raid_count", [session, faction_id])

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

static func _faction_front_state(session: SessionStateStoreScript.SessionData, faction_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyTurnRules._faction_front_state", [session, faction_id])

static func _latest_enemy_state(session: SessionStateStoreScript.SessionData, faction_id: String, fallback: Dictionary) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyTurnRules._latest_enemy_state", [session, faction_id, fallback])

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
	return TurnEngine.native_writing(&"EnemyTurnRules._valid_enemy_faction_configs", [configs])

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
	return TurnEngine.native_writing(&"EnemyTurnRules._config_was_runtime_defaulted", [source, normalized])

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
	return TurnEngine.native_writing(&"EnemyTurnRules._owned_town_count", [session, faction_id])

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
	return TurnEngine.native_writing(&"EnemyTurnRules._faction_capital_state", [session, faction_id])

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

static func _raid_threshold_for_strategy(session: SessionStateStoreScript.SessionData, config: Dictionary, faction_id: String, launch_policy_context: Dictionary = {}) -> int:
	return TurnEngine.native_writing(&"EnemyTurnRules._raid_threshold_for_strategy", [session, config, faction_id, launch_policy_context])

static func _max_active_raids_for_strategy(session: SessionStateStoreScript.SessionData, config: Dictionary, faction_id: String, launch_policy_context: Dictionary = {}) -> int:
	return TurnEngine.native_writing(&"EnemyTurnRules._max_active_raids_for_strategy", [session, config, faction_id, launch_policy_context])

static func _enemy_recruit_cost(town: Dictionary, unit_id: String) -> Dictionary:
	return TurnEngine.native_writing(&"EnemyTurnRules._enemy_recruit_cost", [town, unit_id])

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

static func _normalize_posture(value: Variant) -> String:
	var posture = String(value)
	if posture in ["probing", "massing", "raiding", "fortifying", "reorganizing", "collapsed", "attacking", "expanding", "building"]:
		return posture
	return "probing"

static func _normalize_string_array(value: Variant) -> Array:
	var normalized = []
	if not (value is Array):
		return normalized
	for entry in value:
		var item = String(entry)
		if item != "" and item not in normalized:
			normalized.append(item)
	return normalized

static func _find_state(states: Variant, faction_id: String) -> Dictionary:
	if states is Array:
		for state in states:
			if state is Dictionary and PlayerRules.controller_id(state) == faction_id:
				return state
	return {}

static func _town_name(town_state: Dictionary) -> String:
	return TurnEngine.native_writing(&"EnemyTurnRules._town_name", [town_state])

static func _town_controller_faction_id(town_state: Dictionary) -> String:
	return PlayerRules.town_controller_id(town_state)
