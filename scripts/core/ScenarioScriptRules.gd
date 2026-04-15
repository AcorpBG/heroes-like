class_name ScenarioScriptRules
extends RefCounted

const SessionStateStore = preload("res://scripts/core/SessionStateStore.gd")
const ScenarioRules = preload("res://scripts/core/ScenarioRules.gd")
const EnemyTurnRules = preload("res://scripts/core/EnemyTurnRules.gd")
const HeroCommandRules = preload("res://scripts/core/HeroCommandRules.gd")
const ArtifactRules = preload("res://scripts/core/ArtifactRules.gd")

const SCRIPT_STATE_KEY := "scenario_script_state"
const MAX_CHAIN_REACTIONS := 16
const EVENT_LOG_LIMIT := 24

static func _overworld_rules() -> Variant:
	# Validator anchors: OverworldRules.is_tile_visible, OverworldRules._normalize_built_buildings_for_town_state
	return load("res://scripts/core/OverworldRules.gd")

static func _scenario_factory() -> Variant:
	return load("res://scripts/core/ScenarioFactory.gd")

static func build_script_state() -> Dictionary:
	return {
		"fired_hook_ids": [],
		"event_log": [],
	}

static func normalize_script_state(session: SessionStateStore.SessionData) -> void:
	if session == null:
		return

	var state = session.overworld.get(SCRIPT_STATE_KEY, {})
	if not (state is Dictionary):
		state = build_script_state()

	var fired_hook_ids: Array[String] = []
	for hook_id_value in state.get("fired_hook_ids", []):
		var hook_id = String(hook_id_value)
		if hook_id != "" and hook_id not in fired_hook_ids:
			fired_hook_ids.append(hook_id)

	var event_log = []
	for entry in state.get("event_log", []):
		if not (entry is Dictionary):
			continue
		event_log.append(
			{
				"hook_id": String(entry.get("hook_id", "")),
				"day": max(1, int(entry.get("day", session.day))),
				"message": String(entry.get("message", "")),
			}
		)

	while event_log.size() > EVENT_LOG_LIMIT:
		event_log.remove_at(0)

	state["fired_hook_ids"] = fired_hook_ids
	state["event_log"] = event_log
	session.overworld[SCRIPT_STATE_KEY] = state

static func process_hooks(session: SessionStateStore.SessionData) -> Dictionary:
	normalize_script_state(session)
	if session == null or session.scenario_id == "":
		return {"fired_ids": [], "messages": [], "message": ""}

	var scenario = ContentService.get_scenario(session.scenario_id)
	var hooks = _sorted_hooks(scenario.get("script_hooks", []))
	if hooks.is_empty():
		return {"fired_ids": [], "messages": [], "message": ""}

	var state: Dictionary = session.overworld.get(SCRIPT_STATE_KEY, {})
	var fired_hook_ids: Array = state.get("fired_hook_ids", [])
	var fired_ids = []
	var messages = []
	var processed_this_pass = {}
	var iteration_count = 0

	while iteration_count < MAX_CHAIN_REACTIONS:
		var fired_this_iteration = false
		for hook in hooks:
			if not (hook is Dictionary):
				continue
			var hook_id = String(hook.get("id", ""))
			if hook_id == "" or processed_this_pass.has(hook_id):
				continue
			if bool(hook.get("once", true)) and hook_id in fired_hook_ids:
				continue
			if not _conditions_met(session, hook.get("conditions", [])):
				continue

			processed_this_pass[hook_id] = true
			if bool(hook.get("once", true)) and hook_id not in fired_hook_ids:
				fired_hook_ids.append(hook_id)

			var effect_result = _apply_effects(session, hook.get("effects", []))
			var hook_messages: Array = effect_result.get("messages", [])
			if not hook_messages.is_empty():
				messages.append_array(hook_messages)
			_append_event_log(session, hook_id, hook_messages)
			fired_ids.append(hook_id)
			fired_this_iteration = true

		if not fired_this_iteration:
			break
		iteration_count += 1

	state["fired_hook_ids"] = fired_hook_ids
	session.overworld[SCRIPT_STATE_KEY] = state

	if iteration_count >= MAX_CHAIN_REACTIONS:
		push_warning("Scenario hooks reached the chain reaction cap for session %s." % session.session_id)

	return {
		"fired_ids": fired_ids,
		"messages": messages,
		"message": _join_messages(messages),
	}

static func _sorted_hooks(raw_hooks: Variant) -> Array:
	var hooks = []
	if raw_hooks is Array:
		for hook in raw_hooks:
			if hook is Dictionary:
				hooks.append(hook)
	for index in range(hooks.size()):
		var best_index = index
		for candidate_index in range(index + 1, hooks.size()):
			if _hook_sorts_before(hooks[candidate_index], hooks[best_index]):
				best_index = candidate_index
		if best_index != index:
			var current = hooks[index]
			hooks[index] = hooks[best_index]
			hooks[best_index] = current
	return hooks

static func _hook_sorts_before(candidate: Dictionary, existing: Dictionary) -> bool:
	var candidate_priority = int(candidate.get("priority", 0))
	var existing_priority = int(existing.get("priority", 0))
	if candidate_priority == existing_priority:
		return String(candidate.get("id", "")) < String(existing.get("id", ""))
	return candidate_priority > existing_priority

static func _conditions_met(session: SessionStateStore.SessionData, conditions: Variant) -> bool:
	if not (conditions is Array) or conditions.is_empty():
		return false
	for condition in conditions:
		if not (condition is Dictionary):
			return false
		if not _condition_met(session, condition):
			return false
	return true

static func _condition_met(session: SessionStateStore.SessionData, condition: Dictionary) -> bool:
	match String(condition.get("type", "")):
		"day_at_least":
			return session.day >= int(condition.get("day", 0))
		"town_owned_by_player":
			var town = _find_town(session, condition)
			return not town.is_empty() and String(town.get("owner", "neutral")) == "player"
		"town_not_owned_by_player":
			var town = _find_town(session, condition)
			return town.is_empty() or String(town.get("owner", "neutral")) != "player"
		"flag_true":
			return bool(session.flags.get(String(condition.get("flag", "")), false))
		"session_flag_equals":
			return String(session.flags.get(String(condition.get("flag", "")), "")) == String(condition.get("value", ""))
		"enemy_pressure_at_least":
			return EnemyTurnRules.get_pressure(session, String(condition.get("faction_id", ""))) >= int(condition.get("threshold", 0))
		"encounter_resolved":
			return _encounter_resolved(session, String(condition.get("placement_id", "")))
		"objective_met":
			return ScenarioRules.is_objective_met(
				session,
				String(condition.get("objective_id", "")),
				String(condition.get("bucket", ""))
			)
		"objective_not_met":
			return not ScenarioRules.is_objective_met(
				session,
				String(condition.get("objective_id", "")),
				String(condition.get("bucket", ""))
			)
		"active_raid_count_at_least":
			return EnemyTurnRules.active_raid_count(session, String(condition.get("faction_id", ""))) >= int(condition.get("threshold", 0))
		"active_raid_count_at_most":
			return EnemyTurnRules.active_raid_count(session, String(condition.get("faction_id", ""))) <= int(condition.get("threshold", 0))
		"hook_fired":
			return _hook_fired(session, String(condition.get("hook_id", "")))
		"hook_not_fired":
			return not _hook_fired(session, String(condition.get("hook_id", "")))
		_:
			return false

static func _apply_effects(session: SessionStateStore.SessionData, effects: Variant) -> Dictionary:
	var messages = []
	if not (effects is Array):
		return {"messages": messages}

	for effect in effects:
		if not (effect is Dictionary):
			continue
		var result = _apply_effect(session, effect)
		if result is Dictionary:
			for message_value in result.get("messages", []):
				var message = String(message_value)
				if message != "":
					messages.append(message)

	return {"messages": messages}

static func _apply_effect(session: SessionStateStore.SessionData, effect: Dictionary) -> Dictionary:
	match String(effect.get("type", "")):
		"message":
			var text = String(effect.get("text", ""))
			if text != "":
				return {"messages": [text]}
			return {"messages": []}
		"set_flag":
			var flag = String(effect.get("flag", ""))
			if flag != "":
				session.flags[flag] = effect.get("value", true)
			return {"messages": []}
		"add_resources":
			var resources = _normalize_resources(effect.get("resources", {}))
			_overworld_rules()._add_resources(session, resources)
			var summary = _describe_resources(resources)
			if summary != "":
				return {"messages": ["Received %s." % summary]}
			return {"messages": []}
		"award_experience":
			var amount = max(0, int(effect.get("amount", 0)))
			if amount <= 0:
				return {"messages": []}
			var hero_name = String(session.overworld.get("hero", {}).get("name", "The hero"))
			var messages = ["%s gains %d experience." % [hero_name, amount]]
			messages.append_array(_overworld_rules()._award_experience(session, amount))
			HeroCommandRules.commit_active_hero(session)
			_overworld_rules().refresh_fog_of_war(session)
			return {"messages": messages}
		"award_artifact":
			return _award_artifact(session, String(effect.get("artifact_id", "")))
		"spawn_resource_node":
			return _spawn_resource_node(session, effect.get("placement", {}))
		"spawn_artifact_node":
			return _spawn_artifact_node(session, effect.get("placement", {}))
		"spawn_encounter":
			return _spawn_encounter(session, effect.get("placement", {}))
		"town_add_building":
			return _town_add_building(
				session,
				String(effect.get("placement_id", "")),
				String(effect.get("building_id", ""))
			)
		"town_add_recruits":
			return _town_add_recruits(
				session,
				String(effect.get("placement_id", "")),
				effect.get("recruits", {})
			)
		"add_enemy_pressure":
			return _add_enemy_pressure(
				session,
				String(effect.get("faction_id", "")),
				int(effect.get("amount", 0)),
				int(effect.get("minimum", 0))
			)
		_:
			return {"messages": []}

static func describe_recent_events(session: SessionStateStore.SessionData, limit: int = 2) -> String:
	normalize_script_state(session)
	if session == null:
		return ""
	var state: Dictionary = session.overworld.get(SCRIPT_STATE_KEY, {})
	var event_log = state.get("event_log", [])
	if not (event_log is Array) or event_log.is_empty():
		return ""
	var count = clamp(limit, 1, EVENT_LOG_LIMIT)
	var start_index = max(0, event_log.size() - count)
	var parts = []
	for index in range(start_index, event_log.size()):
		var entry = event_log[index]
		if not (entry is Dictionary):
			continue
		var message = String(entry.get("message", ""))
		if message == "":
			continue
		parts.append("Day %d: %s" % [int(entry.get("day", session.day)), message])
	return " | ".join(parts)

static func _spawn_resource_node(session: SessionStateStore.SessionData, placement: Variant) -> Dictionary:
	if not (placement is Dictionary):
		return {"messages": []}
	var placement_id = String(placement.get("placement_id", ""))
	if placement_id == "" or _node_exists(session.overworld.get("resource_nodes", []), placement_id):
		return {"messages": []}

	var nodes = session.overworld.get("resource_nodes", [])
	var built_nodes: Array = _scenario_factory()._build_resource_states([placement])
	if built_nodes.is_empty():
		return {"messages": []}
	nodes.append(built_nodes[0])
	session.overworld["resource_nodes"] = nodes

	var site = ContentService.get_resource_site(String(placement.get("site_id", "")))
	if not _placement_is_visible(session, placement):
		return {"messages": ["New supplies have been reported beyond current scouting."]}
	return {
		"messages": [
			"%s is uncovered at %d,%d." % [
				String(site.get("name", placement.get("site_id", "Supplies"))),
				int(placement.get("x", 0)),
				int(placement.get("y", 0)),
			]
		]
	}

static func _spawn_artifact_node(session: SessionStateStore.SessionData, placement: Variant) -> Dictionary:
	if not (placement is Dictionary):
		return {"messages": []}
	var placement_id = String(placement.get("placement_id", ""))
	if placement_id == "" or _node_exists(session.overworld.get("artifact_nodes", []), placement_id):
		return {"messages": []}

	var nodes = session.overworld.get("artifact_nodes", [])
	var built_nodes: Array = ArtifactRules.build_artifact_nodes([placement])
	if built_nodes.is_empty():
		return {"messages": []}
	nodes.append(built_nodes[0])
	session.overworld["artifact_nodes"] = nodes

	var artifact = ContentService.get_artifact(String(placement.get("artifact_id", "")))
	if not _placement_is_visible(session, placement):
		return {"messages": ["A relic cache has been reported beyond current scouting."]}
	return {
		"messages": [
			"%s is revealed at %d,%d." % [
				String(artifact.get("name", placement.get("artifact_id", "an artifact"))),
				int(placement.get("x", 0)),
				int(placement.get("y", 0)),
			]
		]
	}

static func _award_artifact(session: SessionStateStore.SessionData, artifact_id: String) -> Dictionary:
	if artifact_id == "":
		return {"messages": []}
	var result: Dictionary = _overworld_rules().award_hero_artifact(session, artifact_id, "Awarded", true, false)
	if not bool(result.get("ok", false)):
		return {"messages": []}
	HeroCommandRules.commit_active_hero(session)
	_overworld_rules().refresh_fog_of_war(session)
	var message = String(result.get("message", ""))
	return {"messages": [message] if message != "" else []}

static func _spawn_encounter(session: SessionStateStore.SessionData, placement: Variant) -> Dictionary:
	if not (placement is Dictionary):
		return {"messages": []}
	var placement_id = String(placement.get("placement_id", ""))
	if placement_id == "" or _node_exists(session.overworld.get("encounters", []), placement_id):
		return {"messages": []}

	var encounter = {
		"placement_id": placement_id,
		"encounter_id": String(placement.get("encounter_id", placement.get("id", ""))),
		"x": int(placement.get("x", 0)),
		"y": int(placement.get("y", 0)),
		"difficulty": String(placement.get("difficulty", "scripted")),
		"combat_seed": int(placement.get("combat_seed", hash("%s:%d:%s" % [session.session_id, session.day, placement_id]))),
	}
	for key in placement.keys():
		var field = String(key)
		if not encounter.has(field):
			encounter[field] = placement[key]

	var encounters = session.overworld.get("encounters", [])
	encounters.append(encounter)
	session.overworld["encounters"] = encounters

	var encounter_template = ContentService.get_encounter(String(encounter.get("encounter_id", "")))
	if not _placement_is_visible(session, encounter):
		return {"messages": ["A hostile force is moving beyond current scouting."]}
	return {
		"messages": [
			"%s emerges at %d,%d." % [
				String(encounter_template.get("name", encounter.get("encounter_id", "Hostiles"))),
				int(encounter.get("x", 0)),
				int(encounter.get("y", 0)),
			]
		]
	}

static func _town_add_building(session: SessionStateStore.SessionData, placement_id: String, building_id: String) -> Dictionary:
	var town_result = _find_town_result(session, placement_id)
	if int(town_result.get("index", -1)) < 0 or building_id == "":
		return {"messages": []}

	var towns = session.overworld.get("towns", [])
	var town = town_result.get("town", {})
	var built_buildings: Array = _overworld_rules()._normalize_built_buildings_for_town_state(town)
	if building_id in built_buildings:
		return {"messages": []}

	built_buildings.append(building_id)
	town["built_buildings"] = built_buildings
	town["built_buildings"] = _overworld_rules()._normalize_built_buildings_for_town_state(town)
	town["available_recruits"] = _overworld_rules()._add_recruit_growth(
		town.get("available_recruits", {}),
		_overworld_rules()._building_growth_payload(building_id)
	)
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns

	var building = ContentService.get_building(building_id)
	var town_label = _town_name(town) if _placement_is_visible(session, town) else "A town beyond current scouting"
	return {
		"messages": [
			"%s raises %s." % [
				town_label,
				String(building.get("name", building_id)),
			]
		]
	}

static func _town_add_recruits(session: SessionStateStore.SessionData, placement_id: String, recruits: Variant) -> Dictionary:
	var town_result = _find_town_result(session, placement_id)
	if int(town_result.get("index", -1)) < 0 or not (recruits is Dictionary):
		return {"messages": []}

	var towns = session.overworld.get("towns", [])
	var town = town_result.get("town", {})
	town["available_recruits"] = _overworld_rules()._add_recruit_growth(
		town.get("available_recruits", {}),
		recruits
	)
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns

	var summary = _describe_recruits(recruits)
	if summary != "":
		var town_label = _town_name(town) if _placement_is_visible(session, town) else "A town beyond current scouting"
		return {
			"messages": [
				"%s receives %s." % [town_label, summary]
			]
		}
	return {"messages": []}

static func _append_event_log(session: SessionStateStore.SessionData, hook_id: String, messages: Array) -> void:
	var state: Dictionary = session.overworld.get(SCRIPT_STATE_KEY, {})
	var event_log = state.get("event_log", [])
	if not (event_log is Array):
		event_log = []
	event_log.append(
		{
			"hook_id": hook_id,
			"day": session.day,
			"message": _join_messages(messages),
		}
	)
	while event_log.size() > EVENT_LOG_LIMIT:
		event_log.remove_at(0)
	state["event_log"] = event_log
	session.overworld[SCRIPT_STATE_KEY] = state

static func _hook_fired(session: SessionStateStore.SessionData, hook_id: String) -> bool:
	if session == null or hook_id == "":
		return false
	var state: Dictionary = session.overworld.get(SCRIPT_STATE_KEY, {})
	var fired_hook_ids = state.get("fired_hook_ids", [])
	return fired_hook_ids is Array and hook_id in fired_hook_ids

static func _node_exists(nodes: Variant, placement_id: String) -> bool:
	if placement_id == "" or not (nodes is Array):
		return false
	for node in nodes:
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return true
	return false

static func _encounter_resolved(session: SessionStateStore.SessionData, placement_id: String) -> bool:
	if placement_id == "":
		return false
	var resolved = session.overworld.get("resolved_encounters", [])
	return resolved is Array and placement_id in resolved

static func _find_town(session: SessionStateStore.SessionData, reference: Dictionary) -> Dictionary:
	return _find_town_result(session, String(reference.get("placement_id", "")), String(reference.get("town_id", ""))).get("town", {})

static func _find_town_result(
	session: SessionStateStore.SessionData,
	placement_id: String,
	town_id: String = ""
) -> Dictionary:
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		if placement_id != "" and String(town.get("placement_id", "")) == placement_id:
			return {"index": index, "town": town}
		if town_id != "" and String(town.get("town_id", "")) == town_id:
			return {"index": index, "town": town}
	return {"index": -1, "town": {}}

static func _add_enemy_pressure(session: SessionStateStore.SessionData, faction_id: String, amount: int, minimum: int = 0) -> Dictionary:
	if session == null or faction_id == "":
		return {"messages": []}
	EnemyTurnRules.normalize_enemy_states(session)
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return {"messages": []}
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var pressure = max(0, int(state.get("pressure", 0)) + max(0, amount))
		if minimum > 0:
			pressure = max(pressure, minimum)
		state["pressure"] = pressure
		states[index] = state
		session.overworld["enemy_states"] = states
		var label = _enemy_label(session, faction_id)
		return {"messages": ["%s pressure rises to %d." % [label, pressure]]}
	return {"messages": []}

static func _enemy_label(session: SessionStateStore.SessionData, faction_id: String) -> String:
	var scenario = ContentService.get_scenario(session.scenario_id if session != null else "")
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return String(config.get("label", faction_id))
	var faction = ContentService.get_faction(faction_id)
	return String(faction.get("name", faction_id))

static func _town_name(town: Dictionary) -> String:
	var town_template = ContentService.get_town(String(town.get("town_id", "")))
	return String(town_template.get("name", town.get("town_id", "Town")))

static func _placement_is_visible(session: SessionStateStore.SessionData, placement: Variant) -> bool:
	if not (placement is Dictionary):
		return false
	return _overworld_rules().is_tile_visible(
		session,
		int(placement.get("x", -1)),
		int(placement.get("y", -1))
	)

static func _normalize_resources(value: Variant) -> Dictionary:
	var resources = {}
	if value is Dictionary:
		for key in value.keys():
			var resource_key = String(key)
			var amount = max(0, int(value[key]))
			if amount > 0 and resource_key in ["gold", "wood", "ore"]:
				resources[resource_key] = amount
	return resources

static func _describe_resources(resources: Variant) -> String:
	if not (resources is Dictionary):
		return ""
	var parts = []
	for key in ["gold", "wood", "ore"]:
		var amount = int(resources.get(key, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, key])
	return ", ".join(parts)

static func _describe_recruits(recruits: Variant) -> String:
	if not (recruits is Dictionary):
		return ""
	var parts = []
	var unit_ids = recruits.keys()
	unit_ids.sort()
	for unit_id_value in unit_ids:
		var unit_id = String(unit_id_value)
		var count = max(0, int(recruits[unit_id_value]))
		if count <= 0:
			continue
		var unit = ContentService.get_unit(unit_id)
		parts.append("%s x%d" % [String(unit.get("name", unit_id)), count])
	return ", ".join(parts)

static func _join_messages(messages: Variant) -> String:
	var parts = []
	if messages is Array:
		for value in messages:
			var message = String(value)
			if message != "":
				parts.append(message)
	return " ".join(parts)
