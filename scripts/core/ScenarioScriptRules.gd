class_name ScenarioScriptRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const EnemyTurnRulesScript = preload("res://scripts/core/EnemyTurnRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const PlayerIdentityRulesScript = preload("res://scripts/core/PlayerIdentityRules.gd")

const SCRIPT_STATE_KEY := "scenario_script_state"
const PENDING_REINFORCEMENTS_KEY := "pending_reinforcements"
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

static func normalize_script_state(session: SessionStateStoreScript.SessionData) -> void:
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

static func process_hooks(session: SessionStateStoreScript.SessionData) -> Dictionary:
	normalize_script_state(session)
	if session == null or session.scenario_id == "":
		return {"fired_ids": [], "messages": [], "message": ""}

	var scenario = ContentService.get_scenario_readonly(session.scenario_id)
	var hooks = _sorted_hooks(scenario.get("script_hooks", []))
	var state: Dictionary = session.overworld.get(SCRIPT_STATE_KEY, {})
	var fired_hook_ids: Array = state.get("fired_hook_ids", [])
	var fired_ids = []
	var messages = []
	var processed_this_pass = {}
	var iteration_count = 0
	# Earned grants are independent of transient hook conditions. Retry only
	# records present on entry; repeatable hooks cannot accumulate a backlog or
	# refire in the same evaluation that delivers their previous invocation.
	var retry_result := _retry_pending_reinforcements(session)
	messages.append_array(retry_result.get("messages", []))
	for hook_id in retry_result.get("hook_ids", []):
		processed_this_pass[hook_id] = true

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

			var effect_result = _apply_effects(session, hook.get("effects", []), hook_id)
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

static func _conditions_met(session: SessionStateStoreScript.SessionData, conditions: Variant) -> bool:
	if not (conditions is Array) or conditions.is_empty():
		return false
	for condition in conditions:
		if not (condition is Dictionary):
			return false
		if not _condition_met(session, condition):
			return false
	return true

static func _condition_met(session: SessionStateStoreScript.SessionData, condition: Dictionary) -> bool:
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
			return EnemyTurnRulesScript.get_pressure(session, String(condition.get("faction_id", ""))) >= int(condition.get("threshold", 0))
		"encounter_resolved":
			return _encounter_resolved(session, String(condition.get("placement_id", "")))
		"objective_met":
			return ScenarioRulesScript.is_objective_met(
				session,
				String(condition.get("objective_id", "")),
				String(condition.get("bucket", ""))
			)
		"objective_not_met":
			return not ScenarioRulesScript.is_objective_met(
				session,
				String(condition.get("objective_id", "")),
				String(condition.get("bucket", ""))
			)
		"active_raid_count_at_least":
			return EnemyTurnRulesScript.active_raid_count(session, String(condition.get("faction_id", ""))) >= int(condition.get("threshold", 0))
		"active_raid_count_at_most":
			return EnemyTurnRulesScript.active_raid_count(session, String(condition.get("faction_id", ""))) <= int(condition.get("threshold", 0))
		"hook_fired":
			return _hook_fired(session, String(condition.get("hook_id", "")))
		"hook_not_fired":
			return not _hook_fired(session, String(condition.get("hook_id", "")))
		_:
			return false

static func _apply_effects(session: SessionStateStoreScript.SessionData, effects: Variant, hook_id: String = "") -> Dictionary:
	var messages = []
	var waiting_messages = []
	if not (effects is Array):
		return {"messages": messages}

	for effect_index in range(effects.size()):
		var effect = effects[effect_index]
		if not (effect is Dictionary):
			continue
		var result = _apply_effect(session, effect)
		if result is Dictionary:
			if String(result.get("reason", "")) == "army_capacity" and hook_id != "":
				waiting_messages.append(_retain_reinforcement(session, hook_id, effect_index, effect, result.get("units", {})))
			for message_value in result.get("messages", []):
				var message = String(message_value)
				if message != "":
					messages.append(message)

	# Clarify after the authored narrative that troops are earned but not yet
	# in an army. Other effects and hook-fired chain semantics remain once-only.
	messages.append_array(waiting_messages)
	return {"messages": messages}

static func _apply_effect(session: SessionStateStoreScript.SessionData, effect: Dictionary) -> Dictionary:
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
			HeroCommandRulesScript.commit_active_hero(session)
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
		"town_add_garrison":
			return _town_add_garrison(
				session,
				String(effect.get("placement_id", "")),
				effect.get("garrison", {})
			)
		"add_army_units":
			return _add_army_units(session, effect.get("units", {}))
		"add_enemy_pressure":
			return _add_enemy_pressure(
				session,
				String(effect.get("faction_id", "")),
				int(effect.get("amount", 0)),
				int(effect.get("minimum", 0))
			)
		_:
			return {"messages": []}

static func describe_recent_events(session: SessionStateStoreScript.SessionData, limit: int = 2) -> String:
	normalize_script_state(session)
	if session == null:
		return ""
	var state: Dictionary = session.overworld.get(SCRIPT_STATE_KEY, {})
	var event_log = state.get("event_log", [])
	if not (event_log is Array):
		event_log = []
	var count = clamp(limit, 1, EVENT_LOG_LIMIT)
	var start_index = max(0, event_log.size() - count)
	var parts = []
	var pending = state.get(PENDING_REINFORCEMENTS_KEY, {})
	if pending is Dictionary and not pending.is_empty():
		parts.append("%d earned reinforcement grant(s) wait for their original army or garrison to have room." % pending.size())
	for index in range(start_index, event_log.size()):
		var entry = event_log[index]
		if not (entry is Dictionary):
			continue
		var message = String(entry.get("message", ""))
		if message == "":
			continue
		parts.append("Day %d: %s" % [int(entry.get("day", session.day)), message])
	return " | ".join(parts)

static func _spawn_resource_node(session: SessionStateStoreScript.SessionData, placement: Variant) -> Dictionary:
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

static func _spawn_artifact_node(session: SessionStateStoreScript.SessionData, placement: Variant) -> Dictionary:
	if not (placement is Dictionary):
		return {"messages": []}
	var placement_id = String(placement.get("placement_id", ""))
	if placement_id == "" or _node_exists(session.overworld.get("artifact_nodes", []), placement_id):
		return {"messages": []}

	var nodes = session.overworld.get("artifact_nodes", [])
	var built_nodes: Array = ArtifactRulesScript.build_artifact_nodes([placement], session.scenario_id)
	if built_nodes.is_empty():
		return {"messages": []}
	var built_node: Dictionary = built_nodes[0]
	nodes.append(built_node)
	session.overworld["artifact_nodes"] = nodes

	var artifact = ContentService.get_artifact(String(built_node.get("artifact_id", "")))
	if not _placement_is_visible(session, placement):
		return {"messages": ["A relic cache has been reported beyond current scouting."]}
	return {
		"messages": [
			"%s is revealed at %d,%d." % [
				String(artifact.get("name", built_node.get("artifact_id", "an artifact"))),
				int(placement.get("x", 0)),
				int(placement.get("y", 0)),
			]
		]
	}

static func _award_artifact(session: SessionStateStoreScript.SessionData, artifact_id: String) -> Dictionary:
	if artifact_id == "":
		return {"messages": []}
	var result: Dictionary = _overworld_rules().award_hero_artifact(session, artifact_id, "Awarded", true, false)
	if not bool(result.get("ok", false)):
		return {"messages": []}
	HeroCommandRulesScript.commit_active_hero(session)
	_overworld_rules().refresh_fog_of_war(session)
	var message = String(result.get("message", ""))
	return {"messages": [message] if message != "" else []}

static func _spawn_encounter(session: SessionStateStoreScript.SessionData, placement: Variant) -> Dictionary:
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

static func _town_add_building(session: SessionStateStoreScript.SessionData, placement_id: String, building_id: String) -> Dictionary:
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

static func _town_add_recruits(session: SessionStateStoreScript.SessionData, placement_id: String, recruits: Variant) -> Dictionary:
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

static func _hero_controller(session: SessionStateStoreScript.SessionData, hero: Dictionary) -> String:
	var controller := String(hero.get("player_id", ""))
	if controller == "":
		controller = String(session.overworld.get("active_player_id", ""))
	return controller if controller != "" else "player"

static func _retain_reinforcement(session: SessionStateStoreScript.SessionData, hook_id: String, effect_index: int, effect: Dictionary, units: Dictionary) -> String:
	var kind := String(effect.get("type", ""))
	var record := {"hook_id": hook_id, "effect_index": effect_index, "kind": kind, "units": units.duplicate(true), "earned_day": session.day}
	var label := "the original army"
	if kind == "add_army_units":
		var hero := HeroCommandRulesScript.active_hero(session)
		record["recipient_id"] = String(hero.get("id", ""))
		record["controller_id"] = _hero_controller(session, hero)
		label = String(hero.get("name", label))
	elif kind == "town_add_garrison":
		var town: Dictionary = _find_town_result(session, String(effect.get("placement_id", ""))).get("town", {})
		record["recipient_id"] = String(town.get("placement_id", ""))
		record["controller_id"] = PlayerIdentityRulesScript.town_controller_id(town)
		record["owner"] = String(town.get("owner", "neutral"))
		label = _town_name(town) if _placement_is_visible(session, town) else "the original town"
	var state: Dictionary = session.overworld.get(SCRIPT_STATE_KEY, {})
	var pending: Dictionary = state.get(PENDING_REINFORCEMENTS_KEY, {})
	var key := "%s:%d" % [hook_id, effect_index]
	if not pending.has(key):
		pending[key] = record
	state[PENDING_REINFORCEMENTS_KEY] = pending
	session.overworld[SCRIPT_STATE_KEY] = state
	return "Earned reinforcements (%s) wait for space in %s's seven army slots; transfer or merge troops to receive them." % [_describe_recruits(units), label]

static func _retry_pending_reinforcements(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var state: Dictionary = session.overworld.get(SCRIPT_STATE_KEY, {})
	var pending = state.get(PENDING_REINFORCEMENTS_KEY, {})
	var messages := []
	var hook_ids := []
	if not (pending is Dictionary) or pending.is_empty():
		return {"messages": messages, "hook_ids": hook_ids}
	var keys: Array = pending.keys()
	keys.sort()
	for key in keys:
		var record = pending[key]
		if not (record is Dictionary):
			continue
		hook_ids.append(String(record.get("hook_id", "")))
		var recipient_id := String(record.get("recipient_id", ""))
		var units = record.get("units", {})
		if recipient_id == "" or not (units is Dictionary) or units.is_empty() or not record.has("controller_id"):
			continue
		# Preserve, but do not materialize, an unrecognized saved grant. Never
		# silently drop part of an earned manifest if its content is unavailable.
		var valid_units := true
		for unit_id in units:
			if int(units[unit_id]) <= 0 or ContentService.get_unit(String(unit_id)).is_empty():
				valid_units = false
				break
		if not valid_units:
			continue
		var delivered := false
		match String(record.get("kind", "")):
			"add_army_units":
				var hero := HeroCommandRulesScript.hero_by_id(session, recipient_id)
				if hero.is_empty() or _hero_controller(session, hero) != String(record.controller_id):
					continue
				var admission := HeroCommandRulesScript.army_addition_plan(hero.get("army", {}).get("stacks", []), units)
				if bool(admission.get("ok", false)):
					HeroCommandRulesScript._set_holder_stacks(session, {}, recipient_id, admission.get("stacks", []))
					delivered = true
			"town_add_garrison":
				var town: Dictionary = _find_town_result(session, recipient_id).get("town", {})
				if town.is_empty() or PlayerIdentityRulesScript.town_controller_id(town) != String(record.controller_id) or String(town.get("owner", "neutral")) != String(record.get("owner", "")):
					continue
				delivered = bool(_town_add_garrison(session, recipient_id, units).get("ok", false))
		if not delivered:
			continue
		pending.erase(key)
		var message := "Waiting reinforcements (%s), earned on day %d, have joined their original army or garrison." % [_describe_recruits(units), int(record.get("earned_day", session.day))]
		messages.append(message)
		_append_event_log(session, String(record.get("hook_id", "")), [message])
	if pending.is_empty():
		state.erase(PENDING_REINFORCEMENTS_KEY)
	else:
		state[PENDING_REINFORCEMENTS_KEY] = pending
	session.overworld[SCRIPT_STATE_KEY] = state
	return {"messages": messages, "hook_ids": hook_ids}

static func _town_add_garrison(session: SessionStateStoreScript.SessionData, placement_id: String, garrison: Variant) -> Dictionary:
	var town_result = _find_town_result(session, placement_id)
	if int(town_result.get("index", -1)) < 0 or not (garrison is Dictionary):
		return {"messages": []}

	var towns = session.overworld.get("towns", [])
	var town = town_result.get("town", {})
	var stacks = town.get("garrison", [])
	var unit_ids = garrison.keys()
	unit_ids.sort()
	var added := {}
	for unit_id_value in unit_ids:
		var unit_id := String(unit_id_value)
		var count := maxi(0, int(garrison.get(unit_id_value, 0)))
		if unit_id != "" and count > 0 and not ContentService.get_unit(unit_id).is_empty():
			added[unit_id] = count
	if added.is_empty():
		return {"messages": []}
	var admission := HeroCommandRulesScript.army_addition_plan(stacks, added)
	if not bool(admission.get("ok", false)):
		return {"ok": false, "reason": "army_capacity", "units": added, "messages": []}
	stacks = admission.get("stacks", [])
	town["garrison"] = stacks
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns

	var summary = _describe_recruits(added)
	if summary != "":
		var town_label = _town_name(town) if _placement_is_visible(session, town) else "A town beyond current scouting"
		return {"ok": true, "messages": ["%s garrisons %s." % [town_label, summary]]}
	return {"ok": true, "messages": []}

static func _add_army_units(session: SessionStateStoreScript.SessionData, units: Variant) -> Dictionary:
	if session == null or not (units is Dictionary) or units.is_empty():
		return {"messages": []}
	var army: Dictionary = session.overworld.get("army", {}).duplicate(true) if session.overworld.get("army", {}) is Dictionary else {}
	if army.is_empty():
		return {"messages": []}
	var stacks: Array = army.get("stacks", []).duplicate(true) if army.get("stacks", []) is Array else []
	var unit_ids: Array = units.keys()
	unit_ids.sort()
	var added := {}
	for unit_id_value in unit_ids:
		var unit_id := String(unit_id_value)
		var count: int = max(0, int(units.get(unit_id_value, 0)))
		if unit_id == "" or count <= 0 or ContentService.get_unit(unit_id).is_empty():
			continue
		added[unit_id] = count
	if added.is_empty():
		return {"messages": []}
	var admission := HeroCommandRulesScript.army_addition_plan(stacks, added)
	if not bool(admission.get("ok", false)):
		return {"ok": false, "reason": "army_capacity", "units": added, "messages": []}
	stacks = admission.get("stacks", [])
	army["stacks"] = stacks
	session.overworld["army"] = army
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true) if session.overworld.get("hero", {}) is Dictionary else {}
	if not hero.is_empty():
		hero["army"] = army.duplicate(true)
		session.overworld["hero"] = hero
	HeroCommandRulesScript.commit_active_hero(session)
	var summary := _describe_recruits(added)
	return {"messages": ["Field reinforcements join the active army (%s)." % summary]} if summary != "" else {"messages": []}

static func _append_event_log(session: SessionStateStoreScript.SessionData, hook_id: String, messages: Array) -> void:
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

static func _hook_fired(session: SessionStateStoreScript.SessionData, hook_id: String) -> bool:
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

static func _encounter_resolved(session: SessionStateStoreScript.SessionData, placement_id: String) -> bool:
	if placement_id == "":
		return false
	var resolved = session.overworld.get("resolved_encounters", [])
	return resolved is Array and placement_id in resolved

static func _find_town(session: SessionStateStoreScript.SessionData, reference: Dictionary) -> Dictionary:
	return _find_town_result(session, String(reference.get("placement_id", "")), String(reference.get("town_id", ""))).get("town", {})

static func _find_town_result(
	session: SessionStateStoreScript.SessionData,
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

static func _add_enemy_pressure(session: SessionStateStoreScript.SessionData, faction_id: String, amount: int, minimum: int = 0) -> Dictionary:
	if session == null or faction_id == "":
		return {"messages": []}
	EnemyTurnRulesScript.normalize_enemy_states(session)
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

static func _enemy_label(session: SessionStateStoreScript.SessionData, faction_id: String) -> String:
	var scenario = ContentService.get_scenario_readonly(session.scenario_id if session != null else "")
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return String(config.get("label", faction_id))
	var faction = ContentService.get_faction(faction_id)
	return String(faction.get("name", faction_id))

static func _town_name(town: Dictionary) -> String:
	var town_template = ContentService.get_town(String(town.get("town_id", "")))
	return String(town_template.get("name", town.get("town_id", "Town")))

static func _placement_is_visible(session: SessionStateStoreScript.SessionData, placement: Variant) -> bool:
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
			if amount > 0 and resource_key != "experience" and resource_key != "":
				resources[resource_key] = amount
	return resources

static func _describe_resources(resources: Variant) -> String:
	if not (resources is Dictionary):
		return ""
	var parts = []
	var keys = resources.keys()
	keys.sort()
	for key in keys:
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
