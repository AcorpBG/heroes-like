class_name BattleRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const DifficultyRulesScript = preload("res://scripts/core/DifficultyRules.gd")
const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const BattleAiRulesScript = preload("res://scripts/core/BattleAiRules.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")

const STATUS_HARRIED := "status_harried"
const STATUS_STAGGERED := "status_staggered"
const RECENT_EVENT_LIMIT := 6
const TACTICAL_BRIEFING_KEY := "tactical_briefing"
const FIELD_OBJECTIVES_KEY := "field_objectives"
const COHESION_MIN := 0
const COHESION_MAX := 10
const MOMENTUM_MAX := 4

static func create_town_assault_payload(
	session: SessionStateStoreScript.SessionData,
	town_placement_id: String
) -> Dictionary:
	OverworldRulesScript.normalize_overworld_state(session)
	var town_result = _find_town_by_placement(session, town_placement_id)
	if int(town_result.get("index", -1)) < 0:
		return {}
	var town: Dictionary = town_result.get("town", {})
	if town.is_empty() or String(town.get("owner", "neutral")) != "enemy":
		return {}
	var town_template: Dictionary = ContentService.get_town(String(town.get("town_id", "")))
	var placement := {
		"placement_id": "town_assault:%s" % town_placement_id,
		"encounter_id": "encounter_town_assault",
		"x": int(town.get("x", 0)),
		"y": int(town.get("y", 0)),
		"combat_seed": hash("%s:%d:town_assault:%s" % [session.session_id, session.day, town_placement_id]),
		"enemy_army": {
			"id": "town_garrison_%s" % town_placement_id,
			"name": "%s Garrison" % _town_name(town),
			"stacks": town.get("garrison", []).duplicate(true) if town.get("garrison", []) is Array else [],
		},
		"enemy_hero_override": _town_captain_state(town),
		"battle_context": {
			"type": "town_assault",
			"town_placement_id": town_placement_id,
			"trigger_faction_id": String(town_template.get("faction_id", "")),
		},
	}
	return create_battle_payload(session, placement)

static func create_battle_payload(session: SessionStateStoreScript.SessionData, encounter_placement: Dictionary) -> Dictionary:
	OverworldRulesScript.normalize_overworld_state(session)
	encounter_placement = _resolved_encounter_placement(session, encounter_placement)
	var encounter_id = String(encounter_placement.get("encounter_id", encounter_placement.get("id", "")))
	var encounter = ContentService.get_encounter(encounter_id)
	if encounter.is_empty():
		return {}

	var scenario = ContentService.get_scenario(session.scenario_id)
	var battle_context = _normalized_battle_context(session, encounter_placement)
	var player_setup = _player_setup_for_battle(session, encounter_placement, battle_context)
	var enemy_army = _enemy_army_for_battle(session, encounter_placement, encounter, battle_context)
	var enemy_hero_state = _enemy_commander_state_for_battle(session, encounter_placement, encounter, battle_context)
	var player_commander_state = player_setup.get("commander_state", session.overworld.get("hero", {}))
	var battlefield_tags = _normalized_battlefield_tags(encounter, battle_context)
	var battle = {
		"position": {
			"x": int(encounter_placement.get("x", OverworldRulesScript.hero_position(session).x)),
			"y": int(encounter_placement.get("y", OverworldRulesScript.hero_position(session).y)),
		},
		"encounter_id": encounter_id,
		"encounter_name": _battle_name(session, encounter, battle_context),
		"resolved_key": OverworldRulesScript.encounter_key(encounter_placement),
		"terrain": String(encounter.get("terrain", "plains")),
		"battlefield_tags": battlefield_tags,
		"combat_seed": int(encounter_placement.get("combat_seed", 0)),
		"round": 1,
		"max_rounds": max(1, int(encounter.get("max_rounds", 12))),
		"distance": _starting_distance_for_encounter(encounter, battle_context),
		"context": battle_context,
		"retreat_allowed": not _is_town_defense_context(battle_context),
		"surrender_allowed": not _is_town_defense_context(battle_context),
		"player_commander_state": player_commander_state.duplicate(true) if player_commander_state is Dictionary else {},
		"player_commander_source": player_setup.get("commander_source", {}),
		"player_hero": _hero_payload_from_state(
			player_commander_state,
			ArtifactRulesScript.aggregate_bonuses(player_commander_state),
			session,
			"player"
		),
		"enemy_hero": enemy_hero_state,
		"enemy_hero_payload": _hero_payload_from_state(enemy_hero_state, {}, session, "enemy"),
		"stacks": [],
		"turn_order": [],
		"turn_index": 0,
		"active_stack_id": "",
		"selected_target_id": "",
		"recent_events": [],
		FIELD_OBJECTIVES_KEY: _normalize_field_objectives(
			[],
			encounter,
			encounter_placement,
			scenario,
			battle_context
		),
		TACTICAL_BRIEFING_KEY: {
			"signature": "%s|%s" % [encounter_id, OverworldRulesScript.encounter_key(encounter_placement)],
			"shown": false,
			"shown_round": 0,
		},
	}

	var stacks = []
	var player_stacks = player_setup.get("stacks", [])
	for index in range(player_stacks.size()):
		var stack = player_stacks[index]
		if stack is Dictionary and int(stack.get("count", 0)) > 0:
			stacks.append(
				_build_battle_stack(
					String(stack.get("unit_id", "")),
					int(stack.get("count", 0)),
					"player",
					index,
					stack.get("source", {})
				)
			)

	var enemy_stacks = enemy_army.get("stacks", [])
	for index in range(enemy_stacks.size()):
		var stack = enemy_stacks[index]
		if stack is Dictionary and int(stack.get("count", 0)) > 0:
			stacks.append(
				_build_battle_stack(
					String(stack.get("unit_id", "")),
					int(stack.get("count", 0)),
					"enemy",
					index,
					_enemy_stack_source(encounter_placement, battle_context)
				)
			)

	battle["stacks"] = stacks
	_prepare_round(battle, 1)
	return battle

static func normalize_battle_state_bridge(session) -> bool:
	return normalize_battle_state(session)

static func _resolved_encounter_placement(session: SessionStateStoreScript.SessionData, encounter_placement: Dictionary) -> Dictionary:
	if session == null:
		return encounter_placement
	var resolved_key = OverworldRulesScript.encounter_key(encounter_placement)
	for placement_value in session.overworld.get("encounters", []):
		if not (placement_value is Dictionary):
			continue
		if OverworldRulesScript.encounter_key(placement_value) == resolved_key:
			return placement_value
	return encounter_placement

static func _normalized_battle_context(session: SessionStateStoreScript.SessionData, raw_context: Variant) -> Dictionary:
	var context = {}
	if raw_context is Dictionary:
		if raw_context.has("battle_context") and raw_context.get("battle_context", {}) is Dictionary:
			context = raw_context.get("battle_context", {})
		else:
			context = raw_context
	var context_type = String(context.get("type", ""))
	if context_type == "" and raw_context is Dictionary:
		var placement = raw_context
		if String(placement.get("spawned_by_faction_id", "")) != "" and String(placement.get("target_kind", "")) == "town":
			var target_town = _find_town_by_placement(session, String(placement.get("target_placement_id", ""))).get("town", {})
			if not target_town.is_empty() and String(target_town.get("owner", "neutral")) == "player":
				context = {
					"type": "town_defense",
					"town_placement_id": String(target_town.get("placement_id", placement.get("target_placement_id", ""))),
					"defending_hero_id": "",
					"raid_encounter_key": OverworldRulesScript.encounter_key(placement),
					"trigger_faction_id": String(placement.get("spawned_by_faction_id", "")),
				}
				context_type = "town_defense"
	var delivery_context: Dictionary = OverworldRulesScript.delivery_interception_context_for_encounter(
		session,
		raw_context if raw_context is Dictionary else {}
	)
	var delivery_node_placement_id: String = String(context.get("delivery_node_placement_id", delivery_context.get("node_placement_id", "")))
	var delivery_site_name: String = String(context.get("delivery_site_name", delivery_context.get("site_name", "")))
	var delivery_origin_town_id: String = String(context.get("delivery_origin_town_id", delivery_context.get("origin_town_id", "")))
	var delivery_origin_town_label: String = String(context.get("delivery_origin_town_label", delivery_context.get("origin_town_label", "")))
	var delivery_target_kind: String = String(context.get("delivery_target_kind", delivery_context.get("target_kind", "")))
	var delivery_target_id: String = String(context.get("delivery_target_id", delivery_context.get("target_id", "")))
	var delivery_target_label: String = String(context.get("delivery_target_label", delivery_context.get("target_label", "")))
	var delivery_route_label: String = String(context.get("delivery_route_label", delivery_context.get("route_label", "")))
	var delivery_pressure_label: String = String(context.get("delivery_pressure_label", delivery_context.get("pressure_label", "")))
	var delivery_recruit_summary: String = String(context.get("delivery_recruit_summary", delivery_context.get("recruit_summary", "")))
	var delivery_arrival_day: int = maxi(0, int(context.get("delivery_arrival_day", delivery_context.get("arrival_day", 0))))
	if context_type == "hero_intercept":
		return {
			"type": "hero_intercept",
			"town_placement_id": "",
			"town_role": "frontier",
			"battlefront_summary": "",
			"battlefront_tags": [],
			"target_hero_id": String(context.get("target_hero_id", "")),
			"trigger_faction_id": String(context.get("trigger_faction_id", "")),
			"delivery_node_placement_id": delivery_node_placement_id,
			"delivery_site_name": delivery_site_name,
			"delivery_origin_town_id": delivery_origin_town_id,
			"delivery_origin_town_label": delivery_origin_town_label,
			"delivery_target_kind": delivery_target_kind,
			"delivery_target_id": delivery_target_id,
			"delivery_target_label": delivery_target_label,
			"delivery_route_label": delivery_route_label,
			"delivery_pressure_label": delivery_pressure_label,
			"delivery_recruit_summary": delivery_recruit_summary,
			"delivery_arrival_day": delivery_arrival_day,
		}
	if context_type not in ["town_defense", "town_assault"]:
		return {
			"type": "encounter",
			"town_placement_id": "",
			"town_role": "frontier",
			"battlefront_summary": "",
			"battlefront_tags": [],
			"delivery_node_placement_id": delivery_node_placement_id,
			"delivery_site_name": delivery_site_name,
			"delivery_origin_town_id": delivery_origin_town_id,
			"delivery_origin_town_label": delivery_origin_town_label,
			"delivery_target_kind": delivery_target_kind,
			"delivery_target_id": delivery_target_id,
			"delivery_target_label": delivery_target_label,
			"delivery_route_label": delivery_route_label,
			"delivery_pressure_label": delivery_pressure_label,
			"delivery_recruit_summary": delivery_recruit_summary,
			"delivery_arrival_day": delivery_arrival_day,
	}
	var town = _find_town_by_placement(session, String(context.get("town_placement_id", ""))).get("town", {})
	var battlefront = OverworldRulesScript.town_battlefront_profile(town)
	return {
		"type": context_type,
		"town_placement_id": String(context.get("town_placement_id", "")),
		"defending_hero_id": String(context.get("defending_hero_id", "")),
		"raid_encounter_key": String(context.get("raid_encounter_key", "")),
		"trigger_faction_id": String(context.get("trigger_faction_id", "")),
		"town_role": OverworldRulesScript.town_strategic_role(town),
		"battlefront_summary": String(battlefront.get("summary", "")),
		"battlefront_tags": battlefront.get("tags", []),
		"delivery_node_placement_id": delivery_node_placement_id,
		"delivery_site_name": delivery_site_name,
		"delivery_origin_town_id": delivery_origin_town_id,
		"delivery_origin_town_label": delivery_origin_town_label,
		"delivery_target_kind": delivery_target_kind,
		"delivery_target_id": delivery_target_id,
		"delivery_target_label": delivery_target_label,
		"delivery_route_label": delivery_route_label,
		"delivery_pressure_label": delivery_pressure_label,
		"delivery_recruit_summary": delivery_recruit_summary,
		"delivery_arrival_day": delivery_arrival_day,
	}

static func _is_town_defense_context(context: Variant) -> bool:
	return context is Dictionary and String(context.get("type", "")) == "town_defense"

static func _is_town_assault_context(context: Variant) -> bool:
	return context is Dictionary and String(context.get("type", "")) == "town_assault"

static func _has_delivery_context(context: Variant) -> bool:
	return context is Dictionary and String(context.get("delivery_node_placement_id", "")) != ""

static func _battle_name(session: SessionStateStoreScript.SessionData, encounter: Dictionary, battle_context: Dictionary) -> String:
	if _is_town_assault_context(battle_context):
		var town_name = _town_name_from_placement_id(session, String(battle_context.get("town_placement_id", "")))
		if town_name != "":
			return "Assault on %s" % town_name
	if _is_town_defense_context(battle_context):
		var town_name = _town_name_from_placement_id(session, String(battle_context.get("town_placement_id", "")))
		if town_name != "":
			return "%s at %s" % [String(encounter.get("name", encounter.get("id", "Raid"))), town_name]
	if String(battle_context.get("type", "")) == "hero_intercept":
		var hero_name := String(
			HeroCommandRulesScript.hero_by_id(session, String(battle_context.get("target_hero_id", ""))).get("name", "")
		)
		if hero_name != "":
			return "%s intercepts %s" % [String(encounter.get("name", encounter.get("id", "Raid"))), hero_name]
	return String(encounter.get("name", encounter.get("id", "Battle")))

static func _enemy_stack_source(encounter_placement: Dictionary, battle_context: Dictionary) -> Dictionary:
	if _is_town_assault_context(battle_context):
		return {
			"source_type": "town_garrison",
			"town_placement_id": String(battle_context.get("town_placement_id", "")),
		}
	return {
		"source_type": "encounter_army",
		"encounter_key": OverworldRulesScript.encounter_key(encounter_placement),
	}

static func _enemy_army_for_encounter(encounter_placement: Dictionary, encounter: Dictionary) -> Dictionary:
	var enemy_army = ContentService.get_army_group(String(encounter.get("enemy_group_id", "")))
	var placement_army = encounter_placement.get("enemy_army", {})
	if placement_army is Dictionary and placement_army.get("stacks", []) is Array and not placement_army.get("stacks", []).is_empty():
		enemy_army = placement_army
	return enemy_army

static func _enemy_army_for_battle(
	session: SessionStateStoreScript.SessionData,
	encounter_placement: Dictionary,
	encounter: Dictionary,
	battle_context: Dictionary
) -> Dictionary:
	if _is_town_assault_context(battle_context):
		var town = _find_town_by_placement(session, String(battle_context.get("town_placement_id", ""))).get("town", {})
		return {
			"id": "town_garrison_%s" % String(battle_context.get("town_placement_id", "")),
			"name": "%s Garrison" % _town_name(town),
			"stacks": town.get("garrison", []).duplicate(true) if town.get("garrison", []) is Array else [],
		}
	return _enemy_army_for_encounter(encounter_placement, encounter)

static func _enemy_commander_state_for_battle(
	session: SessionStateStoreScript.SessionData,
	encounter_placement: Dictionary,
	encounter: Dictionary,
	battle_context: Dictionary
) -> Dictionary:
	var override = encounter_placement.get("enemy_hero_override", {})
	if override is Dictionary and not override.is_empty():
		return override.duplicate(true)
	if _is_town_assault_context(battle_context):
		var town = _find_town_by_placement(session, String(battle_context.get("town_placement_id", ""))).get("town", {})
		return _town_captain_state(town)
	return _enemy_commander_state(encounter)

static func _player_setup_for_battle(
	session: SessionStateStoreScript.SessionData,
	encounter_placement: Dictionary,
	battle_context: Dictionary
) -> Dictionary:
	if not _is_town_defense_context(battle_context):
		var active_hero = session.overworld.get("hero", {})
		return {
			"commander_state": active_hero,
			"commander_source": {
				"type": "active_hero",
				"hero_id": String(active_hero.get("id", "")),
			},
			"stacks": _army_stack_descriptors(
				session.overworld.get("army", {}),
				{
					"source_type": "hero_army",
					"hero_id": String(active_hero.get("id", "")),
				}
			),
		}

	var town = _find_town_by_placement(session, String(battle_context.get("town_placement_id", ""))).get("town", {})
	var defending_hero = _town_defending_hero(session, town, String(battle_context.get("defending_hero_id", "")))
	var commander_state = defending_hero if not defending_hero.is_empty() else _town_captain_state(town)
	var commander_source = {
		"type": "town_hero" if not defending_hero.is_empty() else "town_captain",
		"hero_id": String(defending_hero.get("id", "")),
		"town_placement_id": String(town.get("placement_id", "")),
	}
	var player_stacks = []
	if not defending_hero.is_empty():
		player_stacks.append_array(
			_army_stack_descriptors(
				defending_hero.get("army", {}),
				{
					"source_type": "hero_army",
					"hero_id": String(defending_hero.get("id", "")),
					"town_placement_id": String(town.get("placement_id", "")),
				}
			)
		)
	player_stacks.append_array(
		_army_stack_descriptors(
			{"stacks": town.get("garrison", [])},
			{
				"source_type": "town_garrison",
				"town_placement_id": String(town.get("placement_id", "")),
			}
		)
	)
	return {
		"commander_state": commander_state,
		"commander_source": commander_source,
		"stacks": player_stacks,
	}

static func _normalize_player_commander_state(
	session: SessionStateStoreScript.SessionData,
	existing_state: Variant,
	source: Variant,
	context: Variant
) -> Dictionary:
	if existing_state is Dictionary and not existing_state.is_empty():
		if String((source if source is Dictionary else {}).get("type", "")) == "town_captain":
			return _normalize_town_captain(existing_state)
		return HeroProgressionRulesScript.ensure_hero_progression(SpellRulesScript.ensure_hero_spellbook(existing_state))
	var source_type = String((source if source is Dictionary else {}).get("type", ""))
	if source_type in ["active_hero", "town_hero"]:
		var hero = HeroCommandRulesScript.hero_by_id(session, String((source if source is Dictionary else {}).get("hero_id", "")))
		if not hero.is_empty():
			return hero
	if _is_town_defense_context(context):
		var town = _find_town_by_placement(session, String((context if context is Dictionary else {}).get("town_placement_id", ""))).get("town", {})
		return _town_captain_state(town)
	return session.overworld.get("hero", {})

static func _player_commander_state(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return {}
	if session.battle.is_empty():
		return session.overworld.get("hero", {})
	var commander = session.battle.get("player_commander_state", {})
	return commander if commander is Dictionary else session.overworld.get("hero", {})

static func _army_stack_descriptors(army: Variant, source: Dictionary) -> Array:
	var descriptors = []
	if not (army is Dictionary):
		return descriptors
	for stack_value in army.get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var unit_id = String(stack_value.get("unit_id", ""))
		var count = max(0, int(stack_value.get("count", 0)))
		if unit_id == "" or count <= 0:
			continue
		descriptors.append(
			{
				"unit_id": unit_id,
				"count": count,
				"source": source.duplicate(true),
			}
		)
	return descriptors

static func _town_defending_hero(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	preferred_hero_id: String = ""
) -> Dictionary:
	if session == null or town.is_empty():
		return {}
	var candidates = []
	for hero_value in session.overworld.get("player_heroes", []):
		if not (hero_value is Dictionary):
			continue
		if int(hero_value.get("position", {}).get("x", -1)) != int(town.get("x", -2)):
			continue
		if int(hero_value.get("position", {}).get("y", -1)) != int(town.get("y", -2)):
			continue
		candidates.append(hero_value)
	if candidates.is_empty():
		return {}
	if preferred_hero_id != "":
		for hero in candidates:
			if String(hero.get("id", "")) == preferred_hero_id:
				return hero
	for hero in candidates:
		if String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			return hero
	for hero in candidates:
		if bool(hero.get("is_primary", false)):
			return hero
	return candidates[0]

static func _town_captain_state(town: Dictionary) -> Dictionary:
	var name = "%s Watch Captain" % _town_name(town)
	var category_counts = _town_building_category_counts(town)
	var command = {
		"attack": clamp(int(category_counts.get("dwelling", 0) / 2), 0, 3),
		"defense": clamp(1 + int(category_counts.get("support", 0)) + int(category_counts.get("civic", 0) / 2), 1, 5),
		"power": clamp(int(category_counts.get("magic", 0) / 2), 0, 2),
		"knowledge": clamp(int(category_counts.get("magic", 0)), 0, 2),
	}
	return _normalize_town_captain(
		{
			"id": "town_captain:%s" % String(town.get("placement_id", "")),
			"name": name,
			"level": 1,
			"experience": 0,
			"next_level_experience": 250,
			"base_movement": 0,
			"command": command,
			"specialties": [],
			"pending_specialty_choices": [],
			"artifacts": ArtifactRulesScript.normalize_hero_artifacts({}),
		}
	)

static func _normalize_town_captain(hero_state: Dictionary) -> Dictionary:
	var command = _normalize_command(hero_state.get("command", {}))
	return SpellRulesScript.ensure_hero_spellbook(
		HeroProgressionRulesScript.ensure_hero_progression(
			{
				"id": String(hero_state.get("id", "")),
				"name": String(hero_state.get("name", "Town Captain")),
				"level": max(1, int(hero_state.get("level", 1))),
				"experience": max(0, int(hero_state.get("experience", 0))),
				"next_level_experience": max(250, int(hero_state.get("next_level_experience", 250))),
				"base_movement": 0,
				"command": command,
				"specialties": [],
				"pending_specialty_choices": [],
				"artifacts": ArtifactRulesScript.normalize_hero_artifacts({}),
			}
		),
		{
			"command": command,
			"starting_spell_ids": [],
		}
	)

static func _town_building_category_counts(town: Dictionary) -> Dictionary:
	var counts = {"civic": 0, "dwelling": 0, "economy": 0, "support": 0, "magic": 0}
	for building_id_value in _normalized_town_buildings(town):
		var category = String(ContentService.get_building(String(building_id_value)).get("category", "support"))
		if not counts.has(category):
			category = "support"
		counts[category] = int(counts.get(category, 0)) + 1
	return counts

static func _normalized_town_buildings(town: Dictionary) -> Array:
	var normalized = []
	var template = ContentService.get_town(String(town.get("town_id", "")))
	for building_id_value in template.get("starting_building_ids", []):
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

static func _find_town_by_placement(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	if session == null or placement_id == "":
		return {"index": -1, "town": {}}
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return {"index": index, "town": town}
	return {"index": -1, "town": {}}

static func _find_encounter_by_key(session: SessionStateStoreScript.SessionData, encounter_key: String) -> Dictionary:
	if session == null or encounter_key == "":
		return {"index": -1, "encounter": {}}
	var encounters = session.overworld.get("encounters", [])
	for index in range(encounters.size()):
		var encounter = encounters[index]
		if encounter is Dictionary and OverworldRulesScript.encounter_key(encounter) == encounter_key:
			return {"index": index, "encounter": encounter}
	return {"index": -1, "encounter": {}}

static func _town_name_from_placement_id(session: SessionStateStoreScript.SessionData, placement_id: String) -> String:
	var town = _find_town_by_placement(session, placement_id).get("town", {})
	return _town_name(town)

static func _town_name(town: Dictionary) -> String:
	if town.is_empty():
		return ""
	var template = ContentService.get_town(String(town.get("town_id", "")))
	return String(template.get("name", town.get("town_id", "Town")))

static func normalize_battle_state(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null or session.battle.is_empty():
		return false
	session.save_version = SessionStateStoreScript.SAVE_VERSION
	DifficultyRulesScript.normalize_session(session)

	if not session.battle.has("stacks"):
		var encounter_stub = {
			"encounter_id": String(session.battle.get("encounter_id", "")),
			"x": int(session.battle.get("position", {}).get("x", 0)),
			"y": int(session.battle.get("position", {}).get("y", 0)),
			"combat_seed": int(session.battle.get("combat_seed", 0)),
			"placement_id": String(session.battle.get("resolved_key", "")),
		}
		session.battle = create_battle_payload(session, encounter_stub)
		return not session.battle.is_empty()

	var stacks = []
	for stack in session.battle.get("stacks", []):
		var normalized = _normalize_stack(stack)
		if not normalized.is_empty():
			normalized = SpellRulesScript.normalize_stack_effects(normalized)
			stacks.append(normalized)
	session.battle["stacks"] = stacks
	session.battle["context"] = _normalized_battle_context(session, session.battle.get("context", {}))
	session.battle["retreat_allowed"] = bool(
		session.battle.get("retreat_allowed", not _is_town_defense_context(session.battle.get("context", {})))
	)
	session.battle["surrender_allowed"] = bool(
		session.battle.get("surrender_allowed", not _is_town_defense_context(session.battle.get("context", {})))
	)
	session.battle["recent_events"] = _normalize_recent_events(session.battle.get("recent_events", []))
	session.battle[TACTICAL_BRIEFING_KEY] = _normalize_tactical_briefing_state(session.battle.get(TACTICAL_BRIEFING_KEY, {}), session)
	session.battle["round"] = max(1, int(session.battle.get("round", 1)))
	session.battle["max_rounds"] = max(1, int(session.battle.get("max_rounds", 12)))
	session.battle["terrain"] = String(session.battle.get("terrain", "plains"))
	var encounter = ContentService.get_encounter(String(session.battle.get("encounter_id", "")))
	var scenario = ContentService.get_scenario(session.scenario_id)
	var encounter_placement = _current_battle_encounter_placement(session)
	session.battle["battlefield_tags"] = _normalized_battlefield_tags(encounter, session.battle.get("context", {}))
	session.battle[FIELD_OBJECTIVES_KEY] = _normalize_field_objectives(
		session.battle.get(FIELD_OBJECTIVES_KEY, []),
		encounter,
		encounter_placement,
		scenario,
		session.battle.get("context", {})
	)
	session.battle["distance"] = clamp(
		int(session.battle.get("distance", _starting_distance_for_encounter(encounter, session.battle.get("context", {})))),
		0,
		2
	)
	session.battle["player_commander_state"] = _normalize_player_commander_state(
		session,
		session.battle.get("player_commander_state", {}),
		session.battle.get("player_commander_source", {}),
		session.battle.get("context", {})
	)
	session.battle["player_hero"] = _hero_payload_from_state(
		session.battle.get("player_commander_state", {}),
		ArtifactRulesScript.aggregate_bonuses(session.battle.get("player_commander_state", {})),
		session,
		"player"
	)
	session.battle["enemy_hero"] = _normalize_enemy_hero_state(session.battle.get("enemy_hero", {}), encounter)
	session.battle["enemy_hero_payload"] = _hero_payload_from_state(session.battle.get("enemy_hero", {}), {}, session, "enemy")

	var current_turn_order = session.battle.get("turn_order", [])
	if int(session.battle.get("round", 1)) <= 1 and current_turn_order is Array and current_turn_order.is_empty():
		_prepare_round(session.battle, 1)
	else:
		var turn_order = session.battle.get("turn_order", [])
		if not (turn_order is Array) or turn_order.is_empty():
			_prepare_round(session.battle, int(session.battle.get("round", 1)))
		else:
			session.battle["turn_order"] = turn_order
			session.battle["turn_index"] = clamp(int(session.battle.get("turn_index", 0)), 0, max(turn_order.size() - 1, 0))
			var active_id = String(session.battle.get("active_stack_id", ""))
			if active_id == "" or _get_stack_by_id(session.battle, active_id).is_empty():
				active_id = _advance_to_next_alive(session.battle, int(session.battle.get("turn_index", 0)))
				session.battle["active_stack_id"] = active_id
			_assign_default_target(session.battle)

	return not session.battle.is_empty()

static func resolve_if_battle_ready(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {"state": "invalid", "message": ""}
	var outcome = _evaluate_outcome(session)
	if String(outcome.get("state", "")) != "":
		return outcome
	return _drain_enemy_turns(session)

static func get_active_stack(battle: Dictionary) -> Dictionary:
	return _get_stack_by_id(battle, String(battle.get("active_stack_id", "")))

static func get_selected_target(battle: Dictionary) -> Dictionary:
	return _get_stack_by_id(battle, String(battle.get("selected_target_id", "")))

static func cycle_target(session: SessionStateStoreScript.SessionData, direction: int) -> void:
	if session == null or session.battle.is_empty():
		return
	var active_stack = get_active_stack(session.battle)
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return

	var enemies = _alive_stacks_for_side(session.battle, "enemy")
	if enemies.is_empty():
		session.battle["selected_target_id"] = ""
		return

	var current_id = String(session.battle.get("selected_target_id", ""))
	var index = 0
	for enemy_index in range(enemies.size()):
		if String(enemies[enemy_index].get("battle_id", "")) == current_id:
			index = enemy_index
			break
	index = posmod(index + direction, enemies.size())
	session.battle["selected_target_id"] = String(enemies[index].get("battle_id", ""))

static func describe_spellbook(session: SessionStateStoreScript.SessionData) -> String:
	if session == null:
		return "Battle Spells | Mana 0/0 | No known spells"
	return SpellRulesScript.describe_spellbook(_player_commander_state(session), SpellRulesScript.CONTEXT_BATTLE)

static func get_spell_actions(session: SessionStateStoreScript.SessionData) -> Array:
	if session == null or session.battle.is_empty():
		return []
	return SpellRulesScript.get_battle_actions(
		_player_commander_state(session),
		session.battle,
		get_active_stack(session.battle),
		get_selected_target(session.battle)
	)

static func describe_header(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "Battle"
	var battle = session.battle
	return String(battle.get("encounter_name", battle.get("encounter_id", "Battle")))

static func describe_status(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "Round 0 | Battlefield unavailable"
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	var status = "Round %d/%d | %s | Terrain %s | %s | Active %s" % [
		int(battle.get("round", 1)),
		int(battle.get("max_rounds", 12)),
		_battle_context_label(session, battle.get("context", {})),
		String(battle.get("terrain", "plains")).capitalize(),
		_distance_label(int(battle.get("distance", 1))),
		String(active_stack.get("name", "No active stack")),
	]
	var objective_brief = _field_objective_status_brief(battle)
	if objective_brief != "":
		status += " | %s" % objective_brief
	return status

static func describe_pressure(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "Outcome pressure unavailable."
	var battle = session.battle
	var player_totals = _army_totals(battle, "player")
	var enemy_totals = _army_totals(battle, "enemy")
	var rounds_remaining = max(0, int(battle.get("max_rounds", 12)) - int(battle.get("round", 1)) + 1)
	var lines = [
		"Friendly line: %d stacks | %d units | %d HP" % [
			int(player_totals.get("stacks", 0)),
			int(player_totals.get("units", 0)),
			int(player_totals.get("health", 0)),
		],
		"Enemy line: %d stacks | %d units | %d HP" % [
			int(enemy_totals.get("stacks", 0)),
			int(enemy_totals.get("units", 0)),
			int(enemy_totals.get("health", 0)),
		],
		"Clock: %d rounds before stalemate" % rounds_remaining,
	]
	var battlefront_summary = _battlefield_identity_summary(battle)
	if battlefront_summary != "":
		lines.append("Battlefront: %s" % battlefront_summary)
	var objective_pressure = _field_objective_pressure_summary(battle)
	if objective_pressure != "":
		lines.append("Objective pressure: %s" % objective_pressure)
	lines.append("Pressure: %s" % _pressure_brief(session))
	lines.append("Retreat: %s" % ("Open" if bool(battle.get("retreat_allowed", true)) else "Locked"))
	lines.append("Surrender: %s" % ("Open" if bool(battle.get("surrender_allowed", true)) else "Locked"))
	return "\n".join(lines)

static func describe_risk_readiness_board(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "Outlook: Tactical risk board unavailable."
	var battle = session.battle
	var lines = [
		"Outlook: %s" % _risk_readiness_grade(session, battle),
		"Initiative swing: %s" % _risk_board_initiative_line(battle),
		"Command posture: %s" % _risk_board_commander_line(battle),
		"Line integrity: %s" % _risk_board_line_integrity_line(battle),
		"Fire lane: %s" % _risk_board_ranged_pressure_line(battle),
		"Priority break: %s" % _risk_board_priority_line(battle),
		"Objective urgency: %s" % _risk_board_objective_line(session, battle),
	]
	var dispatch_line = _risk_board_dispatch_line(battle)
	if dispatch_line != "":
		lines.append("Latest shift: %s" % dispatch_line)
	return "\n".join(lines)

static func describe_tactical_briefing(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return ""
	normalize_battle_state(session)
	if not _should_surface_tactical_briefing(session):
		return ""
	return "\n".join(_tactical_briefing_lines(session))

static func consume_tactical_briefing(session: SessionStateStoreScript.SessionData) -> String:
	var briefing_text = describe_tactical_briefing(session)
	if briefing_text == "":
		return ""
	var briefing_state = session.battle.get(TACTICAL_BRIEFING_KEY, {})
	if not (briefing_state is Dictionary):
		briefing_state = {}
	briefing_state["shown"] = true
	briefing_state["shown_round"] = int(session.battle.get("round", 1))
	session.battle[TACTICAL_BRIEFING_KEY] = briefing_state
	return briefing_text

static func describe_commander_summary(session: SessionStateStoreScript.SessionData, side: String) -> String:
	if session == null or session.battle.is_empty():
		return "Commander summary unavailable."
	var battle = session.battle
	var commander_state = _commander_state_for_side(battle, side)
	var commander_payload = _hero_payload_for_side(battle, side)
	var command = commander_state.get("command", {}) if commander_state is Dictionary else {}
	var army_totals = _army_totals(battle, side)
	if commander_state.is_empty():
		return "\n".join(
			[
				"No named commander is attached to this force.",
				"Army: %d stacks | %d units | %d HP | %d ranged" % [
					int(army_totals.get("stacks", 0)),
					int(army_totals.get("units", 0)),
					int(army_totals.get("health", 0)),
					int(army_totals.get("ranged_stacks", 0)),
				],
			]
		)
	var battle_attack = int(commander_payload.get("attack", int(command.get("attack", 0))))
	var battle_defense = int(commander_payload.get("defense", int(command.get("defense", 0))))
	var battle_initiative = int(commander_payload.get("initiative", 0))
	var initiative_label = "%d" % battle_initiative
	if battle_initiative > 0:
		initiative_label = "+%d" % battle_initiative
	return "\n".join(
		[
			"%s | %s" % [
				String(commander_state.get("name", _side_label(side))),
				_commander_role_label(battle, side),
			],
			"Command: Atk %d | Def %d | Power %d | Knowledge %d" % [
				int(command.get("attack", 0)),
				int(command.get("defense", 0)),
				int(command.get("power", 0)),
				int(command.get("knowledge", 0)),
			],
			"Battle aura: Atk %d | Def %d | Init %s" % [
				battle_attack,
				battle_defense,
				initiative_label,
			],
			"Mana %d/%d | Army %d stacks | %d units | %d HP" % [
				int(commander_payload.get("mana_current", 0)),
				int(commander_payload.get("mana_max", 0)),
				int(army_totals.get("stacks", 0)),
				int(army_totals.get("units", 0)),
				int(army_totals.get("health", 0)),
			],
			"Doctrine: %s" % _side_doctrine_summary(battle, side),
		]
	)

static func describe_initiative_track(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "Initiative track unavailable."
	var battle = session.battle
	var turn_order = battle.get("turn_order", [])
	if not (turn_order is Array) or turn_order.is_empty():
		return "Initiative is still being established."
	var lines = []
	for index in range(turn_order.size()):
		var battle_id = String(turn_order[index])
		var stack = _get_stack_by_id(battle, battle_id)
		if stack.is_empty() or _alive_count(stack) <= 0:
			continue
		var marker = "UP"
		if battle_id == String(battle.get("active_stack_id", "")):
			marker = "NOW"
		elif index < int(battle.get("turn_index", 0)):
			marker = "DONE"
		lines.append("%s %s [%s] | Init %d | x%d | HP %d" % [
			marker,
			_stack_label(stack),
			_side_label(String(stack.get("side", ""))),
			_stack_initiative_total(stack, battle),
			_alive_count(stack),
			int(stack.get("total_health", 0)),
		])
	return "\n".join(lines) if not lines.is_empty() else "No active stacks remain."

static func describe_active_context(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "No active stack."
	return _stack_focus_summary(get_active_stack(session.battle), session.battle, true)

static func describe_target_context(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "No target selected."
	var battle = session.battle
	var target = get_selected_target(battle)
	if target.is_empty():
		return "No target selected."
	var summary = _stack_focus_summary(target, battle, false)
	var active_stack = get_active_stack(battle)
	if active_stack.is_empty():
		return summary
	return "%s\nEngagement: %s" % [summary, _engagement_preview(active_stack, target, battle)]

static func describe_effect_board(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "No active effects."
	var lines = []
	for stack in session.battle.get("stacks", []):
		if not (stack is Dictionary) or _alive_count(stack) <= 0:
			continue
		var effect_summary = SpellRulesScript.effect_summary(stack, session.battle)
		if effect_summary != "":
			lines.append("%s [%s]: %s" % [
				_stack_label(stack),
				_side_label(String(stack.get("side", ""))),
				effect_summary,
			])
	return "\n".join(lines) if not lines.is_empty() else "No active spell or status effects are shaping this round."

static func describe_dispatch(session: SessionStateStoreScript.SessionData, last_message: String = "") -> String:
	if session == null or session.battle.is_empty():
		return last_message if last_message != "" else "Battle dispatch unavailable."
	var lines = []
	var latest = last_message.strip_edges()
	if latest != "":
		lines.append("Latest: %s" % latest)
	var appended = 0
	for event_text in session.battle.get("recent_events", []):
		var event_line = String(event_text).strip_edges()
		if event_line == "" or event_line == latest:
			continue
		lines.append("Feed: %s" % event_line)
		appended += 1
		if appended >= 4:
			break
	lines.append("Pressure: %s" % _pressure_brief(session))
	return "\n".join(lines)

static func describe_action_surface(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "No battle orders are available."
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	if active_stack.is_empty():
		return "No stack is ready to act."
	if String(active_stack.get("side", "")) != "player":
		return "%s is acting now. Hold the line until command returns." % _stack_label(active_stack)
	var target = get_selected_target(battle)
	var actions = get_action_surface(session)
	var lines = [
		"Target focus: %s" % String(target.get("name", "No target selected")),
	]
	for action_id in ["advance", "strike", "shoot", "defend", "retreat", "surrender"]:
		var action = actions.get(action_id, {})
		lines.append("%s: %s" % [
			String(action.get("label", action_id.capitalize())),
			String(action.get("summary", "")),
		])
	return "\n".join(lines)

static func describe_order_consequence_board(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "Order Consequences\n- Battle consequence board unavailable."
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	if active_stack.is_empty():
		return "Order Consequences\n- No stack is ready to act."
	if String(active_stack.get("side", "")) != "player":
		var enemy_action = BattleAiRulesScript.choose_enemy_action(
			battle,
			active_stack,
			battle.get("enemy_hero", {})
		)
		return "\n".join(
			[
				"Order Consequences",
				"- Enemy initiative: %s is acting now; the player order window is closed." % _stack_label(active_stack),
				"- Counterpressure: %s" % _enemy_action_preview_summary(battle, active_stack, enemy_action),
				"- Objective pull: %s" % _objective_pull_line(session, battle, {}, active_stack, get_selected_target(battle)),
			]
		)
	var target = get_selected_target(battle)
	var actions = get_action_surface(session)
	return "\n".join(
		[
			"Order Consequences",
			"- Focused order: %s" % _focused_order_line(session, battle, actions, active_stack, target),
			"- Trade window: %s" % _trade_window_line(session, battle, actions, active_stack, target),
			"- Command tools: %s" % _command_tools_line(session, battle, active_stack, target),
			"- Objective pull: %s" % _objective_pull_line(session, battle, actions, active_stack, target),
			"- Enemy reply: %s" % _enemy_reply_line(session, battle),
		]
	)

static func describe_spell_timing_board(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "Spell and Ability Timing\n- Timing board unavailable."
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	var target = get_selected_target(battle)
	return "\n".join(
		[
			"Spell and Ability Timing",
			"- Spell window: %s" % _spell_window_line(session, battle, active_stack, target),
			"- Support payoff: %s" % _support_payoff_line(session, battle, active_stack, target),
			"- Protection need: %s" % _protection_need_line(session, battle, active_stack, target),
			"- Burst risk: %s" % _burst_risk_line(session, battle),
		]
	)

static func _spell_window_line(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> String:
	if active_stack.is_empty():
		return "No active stack is shaping a timing window."
	if String(active_stack.get("side", "")) != "player":
		return _enemy_spell_threat_line(battle, active_stack)
	var preferred_action = _preferred_spell_timing_action(session, battle, active_stack, target)
	if not preferred_action.is_empty():
		return "%s: %s" % [
			String(preferred_action.get("label", "Battle spell")),
			String(preferred_action.get("summary", "A battle spell is ready.")),
		]
	var commander = _player_commander_state(session)
	var mana = SpellRulesScript.mana_state(commander)
	var known_spells = SpellRulesScript.known_spells(commander, SpellRulesScript.CONTEXT_BATTLE)
	if known_spells.is_empty():
		return "No battle spell is authored for this commander; this turn has to come from unit timing."
	if int(mana.get("current", 0)) <= 0:
		return "Mana is dry at %d/%d, so the order has to come from unit timing alone." % [
			int(mana.get("current", 0)),
			int(mana.get("max", 0)),
		]
	if target.is_empty():
		return "Retarget first; the damage spells need a legal enemy stack before the window opens."
	return "No legal spell window is open from this posture; stabilize or change the exchange first."

static func _preferred_spell_timing_action(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> Dictionary:
	var best = {}
	var best_score = -99999.0
	var availability = action_availability(battle)
	for action in get_spell_actions(session):
		if not (action is Dictionary) or bool(action.get("disabled", false)):
			continue
		var spell_id = String(action.get("id", "")).trim_prefix("cast_spell:")
		var spell = ContentService.get_spell(spell_id)
		if spell.is_empty():
			continue
		var score = _spell_timing_action_score(battle, active_stack, target, spell, availability)
		if best.is_empty() or score > best_score:
			best = action
			best_score = score
	return best

static func _spell_timing_action_score(
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary,
	spell: Dictionary,
	availability: Dictionary
) -> float:
	var effect = spell.get("effect", {})
	var effect_type = String(effect.get("type", ""))
	var score = 0.0
	match effect_type:
		"damage_enemy":
			score = 4.0
			if not target.is_empty():
				score += 2.0
				if bool(target.get("ranged", false)):
					score += 1.0
				if _health_ratio(target) <= 0.75:
					score += 1.0
			var status_effect = effect.get("status_effect", {})
			var effect_id = String(status_effect.get("effect_id", status_effect.get("status_id", "")))
			if effect_id != "" and not target.is_empty() and not SpellRulesScript.has_effect_id(target, battle, effect_id):
				score += 1.5
		"defense_buff":
			score = 2.0
			if _stack_cohesion_total(active_stack, battle) <= 5:
				score += 2.5
			if _stack_is_isolated(battle, active_stack):
				score += 1.5
			if int(battle.get("distance", 1)) <= 0 or bool(active_stack.get("defending", false)):
				score += 1.0
		"initiative_buff":
			score = 2.0
			if int(battle.get("round", 1)) <= 2:
				score += 1.5
			if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
				score += 1.5
			if not bool(active_stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
				score += 1.5
		"attack_buff":
			score = 2.0
			if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
				score += 2.0
			if bool(availability.get("shoot", false)) or bool(availability.get("strike", false)):
				score += 1.5
			if not target.is_empty() and _health_ratio(target) <= 0.75:
				score += 1.0
	return score

static func _support_payoff_line(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> String:
	var followup_line = _support_followup_line(battle, target)
	if followup_line != "":
		return followup_line
	if not active_stack.is_empty() and String(active_stack.get("side", "")) == "player":
		var active_ability = _active_ability_window_summary(active_stack, battle, target)
		if active_ability != "":
			return active_ability
	if _side_has_ability(battle, "player", "formation_guard") and _side_defending_count(battle, "player") > 0 and _allied_ranged_count(battle, "player") > 0:
		return "Formation Guard plus defending screens is still feeding the firing line."
	if _side_has_ability(battle, "player", "volley") and int(battle.get("distance", 1)) > 0:
		return "Volley stacks still want the long lane before melee compresses the board."
	if _side_positive_effect_count(battle, "player") > 0 and _battle_has_any_tags(battle, ["battery_nest", "elevated_fire", "open_lane"]):
		return "Positive effects are amplifying the fire lane; spend them before distance closes."
	return "No major support chain is live beyond the base exchange."

static func _support_followup_line(battle: Dictionary, target: Dictionary) -> String:
	var targets = []
	if not target.is_empty() and String(target.get("side", "")) == "enemy":
		targets.append(target)
	for enemy in _alive_stacks_for_side(battle, "enemy"):
		if target.is_empty() or String(enemy.get("battle_id", "")) != String(target.get("battle_id", "")):
			targets.append(enemy)
	for enemy in targets:
		if not (enemy is Dictionary):
			continue
		if SpellRulesScript.has_effect_id(enemy, battle, STATUS_HARRIED):
			var finisher = _first_stack_with_any_ability(battle, "player", ["backstab", "bloodrush", "shielding"])
			if not finisher.is_empty():
				return "%s is harried; %s can cash that mark once contact holds." % [
					_stack_label(enemy),
					_stack_label(finisher),
				]
		if SpellRulesScript.has_effect_id(enemy, battle, STATUS_STAGGERED):
			var punisher = _first_stack_with_any_ability(battle, "player", ["formation_guard", "reach", "brace"])
			if not punisher.is_empty():
				return "%s is staggered; %s can punish the slowed window on the next grounded trade." % [
					_stack_label(enemy),
					_stack_label(punisher),
				]
	return ""

static func _protection_need_line(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> String:
	var protected_stack = _priority_friendly_protection_stack(battle)
	if protected_stack.is_empty():
		return "No friendly stack is demanding emergency cover yet."
	var threat_stack = get_active_stack(battle)
	if threat_stack.is_empty() or String(threat_stack.get("side", "")) != "enemy":
		threat_stack = _next_enemy_reply_stack(battle)
	var threat_label = _stack_label(threat_stack) if not threat_stack.is_empty() else "the next hostile stack"
	if not active_stack.is_empty() and String(active_stack.get("side", "")) == "player" and String(active_stack.get("battle_id", "")) == String(protected_stack.get("battle_id", "")):
		var support_spell = _best_ready_support_spell_action(session, battle, active_stack, target)
		if not support_spell.is_empty():
			return "%s is the exposed lane; %s" % [
				_stack_label(protected_stack),
				String(support_spell.get("summary", "A support spell is ready.")),
			]
		var defend_surface = get_action_surface(session).get("defend", {})
		if defend_surface is Dictionary and not bool(defend_surface.get("disabled", true)):
			return "%s is the exposed lane; %s" % [
				_stack_label(protected_stack),
				String(defend_surface.get("summary", "Defend and hold the line.")),
			]
	if SpellRulesScript.has_any_effect_ids(protected_stack, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
		return "%s is already pressured and there is no authored cleanse in the current spellbook; blunt %s before the burst lands." % [
			_stack_label(protected_stack),
			threat_label,
		]
	if bool(protected_stack.get("ranged", false)):
		return "%s is the soft back-line point; keep screens intact or break %s before it reaches the firing lane." % [
			_stack_label(protected_stack),
			threat_label,
		]
	return "%s is the softest point in the line; trade this turn to keep %s from getting the next clean burst." % [
		_stack_label(protected_stack),
		threat_label,
	]

static func _priority_friendly_protection_stack(battle: Dictionary) -> Dictionary:
	var threat_stack = get_active_stack(battle)
	if threat_stack.is_empty() or String(threat_stack.get("side", "")) != "enemy":
		threat_stack = _next_enemy_reply_stack(battle)
	var threatened_target_id = ""
	if not threat_stack.is_empty():
		var threat_action = BattleAiRulesScript.choose_enemy_action(
			battle,
			threat_stack,
			battle.get("enemy_hero", {})
		)
		threatened_target_id = String(threat_action.get("target_battle_id", ""))
	var best = {}
	var best_score = 0
	for stack in _alive_stacks_for_side(battle, "player"):
		var score = 0
		if String(stack.get("battle_id", "")) == threatened_target_id:
			score += 3
		if _stack_cohesion_total(stack, battle) <= 4:
			score += 3
		elif _stack_cohesion_total(stack, battle) <= 5:
			score += 1
		if _stack_is_isolated(battle, stack):
			score += 2
		if SpellRulesScript.has_any_effect_ids(stack, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
			score += 2
		if _health_ratio(stack) <= 0.6:
			score += 2
		if bool(stack.get("ranged", false)):
			score += 1
		if _stack_has_positive_effect(stack, battle):
			score += 1
		if best.is_empty() or score > best_score:
			best = stack
			best_score = score
	if best_score >= 3:
		return best
	return {}

static func _best_ready_support_spell_action(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> Dictionary:
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return {}
	var best = {}
	var best_score = -99999.0
	for action in get_spell_actions(session):
		if not (action is Dictionary) or bool(action.get("disabled", false)):
			continue
		var spell_id = String(action.get("id", "")).trim_prefix("cast_spell:")
		var spell = ContentService.get_spell(spell_id)
		if spell.is_empty():
			continue
		var effect_type = String(spell.get("effect", {}).get("type", ""))
		if effect_type == "damage_enemy":
			continue
		var score = 0.0
		match effect_type:
			"defense_buff":
				score = 4.0
				if _stack_cohesion_total(active_stack, battle) <= 5:
					score += 2.0
				if _stack_is_isolated(battle, active_stack):
					score += 1.5
			"initiative_buff":
				score = 3.0
				if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
					score += 1.5
				if not bool(active_stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
					score += 1.5
			"attack_buff":
				score = 2.0
				if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
					score += 2.0
				if not target.is_empty() and _health_ratio(target) <= 0.75:
					score += 1.0
		if best.is_empty() or score > best_score:
			best = action
			best_score = score
	return best

static func _burst_risk_line(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var reply_stack = get_active_stack(battle)
	if reply_stack.is_empty() or String(reply_stack.get("side", "")) != "enemy":
		reply_stack = _next_enemy_reply_stack(battle)
	if reply_stack.is_empty():
		return "No hostile reply remains after this exchange."
	var action = BattleAiRulesScript.choose_enemy_action(
		battle,
		reply_stack,
		battle.get("enemy_hero", {})
	)
	if action.is_empty():
		return "No hostile burst line is visible yet."
	var summary = _enemy_action_preview_summary(battle, reply_stack, action)
	var target = _get_stack_by_id(battle, String(action.get("target_battle_id", "")))
	match String(action.get("action", "")):
		"cast_spell":
			var spell = ContentService.get_spell(String(action.get("spell_id", "")))
			var timing_hint = SpellRulesScript.battle_spell_timing_summary(
				battle.get("enemy_hero", {}),
				battle,
				reply_stack,
				target,
				spell
			)
			var suffix = ""
			if timing_hint != "":
				suffix = " %s" % timing_hint
			return "%s%s" % [summary, suffix]
		"shoot":
			if not target.is_empty() and bool(target.get("ranged", false)) and _health_ratio(target) <= 0.75:
				return "%s The enemy is lining up a back-line break on %s." % [summary, _stack_label(target)]
		"strike":
			if not target.is_empty() and _has_ability(reply_stack, "bloodrush") and _health_ratio(target) <= 0.75:
				return "%s Bloodrush is live on %s." % [summary, _stack_label(target)]
			if not target.is_empty() and _has_ability(reply_stack, "backstab") and SpellRulesScript.has_any_effect_ids(target, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
				return "%s Backstab payoff is live on %s." % [summary, _stack_label(target)]
			if _has_ability(reply_stack, "brace") and bool(reply_stack.get("defending", false)):
				return "%s Brace will punish the first stack that overcommits into it." % summary
		"defend":
			if _has_ability(reply_stack, "formation_guard"):
				return "%s Formation Guard will keep the hostile firing line covered." % summary
	return summary

static func _enemy_spell_threat_line(battle: Dictionary, enemy_stack: Dictionary) -> String:
	var action = BattleAiRulesScript.choose_enemy_action(
		battle,
		enemy_stack,
		battle.get("enemy_hero", {})
	)
	if String(action.get("action", "")) != "cast_spell":
		return "%s is acting now; no enemy spell timing window is leading the exchange." % _stack_label(enemy_stack)
	var spell = ContentService.get_spell(String(action.get("spell_id", "")))
	var target = _get_stack_by_id(battle, String(action.get("target_battle_id", "")))
	var timing_hint = SpellRulesScript.battle_spell_timing_summary(
		battle.get("enemy_hero", {}),
		battle,
		enemy_stack,
		target,
		spell
	)
	var target_suffix = ""
	if not target.is_empty():
		target_suffix = " on %s" % _stack_label(target)
	var timing_suffix = ""
	if timing_hint != "":
		timing_suffix = " %s" % timing_hint
	return "%s can cast %s%s.%s" % [
		_stack_label(enemy_stack),
		String(spell.get("name", "a spell")),
		target_suffix,
		timing_suffix,
	]

static func _first_stack_with_any_ability(battle: Dictionary, side: String, ability_ids: Array) -> Dictionary:
	for stack in _alive_stacks_for_side(battle, side):
		for ability_id_value in ability_ids:
			if _has_ability(stack, String(ability_id_value)):
				return stack
	return {}

static func _preferred_player_action_id(surface: Dictionary, active_stack: Dictionary) -> String:
	if not bool(surface.get("shoot", {}).get("disabled", true)) and bool(active_stack.get("ranged", false)):
		return "shoot"
	if not bool(surface.get("strike", {}).get("disabled", true)):
		return "strike"
	if not bool(surface.get("advance", {}).get("disabled", true)):
		return "advance"
	if not bool(surface.get("defend", {}).get("disabled", true)):
		return "defend"
	if not bool(surface.get("retreat", {}).get("disabled", true)):
		return "retreat"
	if not bool(surface.get("surrender", {}).get("disabled", true)):
		return "surrender"
	return ""

static func _focused_order_line(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	surface: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> String:
	var action_id = _preferred_player_action_id(surface, active_stack)
	if action_id == "":
		return "No legal player order is open from this posture."
	var action = surface.get(action_id, {})
	var summary = String(action.get("summary", ""))
	if summary != "":
		return summary
	return _trade_window_line(session, battle, surface, active_stack, target)

static func _trade_window_line(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	surface: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> String:
	if not bool(surface.get("strike", {}).get("disabled", true)):
		return _attack_action_summary(active_stack, target, battle, false)
	if not bool(surface.get("shoot", {}).get("disabled", true)):
		return _attack_action_summary(active_stack, target, battle, true)
	if not bool(surface.get("advance", {}).get("disabled", true)):
		return _advance_action_summary(battle, active_stack)
	if not bool(surface.get("defend", {}).get("disabled", true)):
		return _defend_action_summary(battle, active_stack)
	if not bool(surface.get("retreat", {}).get("disabled", true)):
		return _retreat_action_summary(session)
	if not bool(surface.get("surrender", {}).get("disabled", true)):
		return _surrender_action_summary(session)
	return "No clean trade is available until the initiative changes."

static func _command_tools_line(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> String:
	for action in get_spell_actions(session):
		if not (action is Dictionary):
			continue
		if bool(action.get("disabled", false)):
			continue
		return "Spell: %s" % String(action.get("summary", "A battle spell is ready."))
	var ability_summary = _active_ability_window_summary(active_stack, battle, target)
	if ability_summary != "":
		return ability_summary
	return "No live spell or ability edge is opening beyond the base exchange."

static func _objective_pull_line(
	session: SessionStateStoreScript.SessionData,
	battle: Dictionary,
	surface: Dictionary,
	active_stack: Dictionary,
	target: Dictionary
) -> String:
	if not active_stack.is_empty() and String(active_stack.get("side", "")) == "player":
		var action_id = _preferred_player_action_id(surface, active_stack)
		if action_id != "":
			var preview = _field_objective_action_preview(
				battle,
				{
					"action": action_id,
					"side": "player",
					"battle_id": String(active_stack.get("battle_id", "")),
					"target_battle_id": String(target.get("battle_id", "")),
				}
			)
			if preview != "":
				return preview
	var urgency = _field_objective_urgency_summary(session, battle)
	if urgency != "":
		return urgency
	var scenario = ContentService.get_scenario(session.scenario_id)
	var encounter_objective = _encounter_objective_for_battle(session, battle, scenario)
	if not encounter_objective.is_empty():
		return "Clearing this host advances %s." % ScenarioRulesScript._objective_label(session, encounter_objective)
	var objective_brief = _field_objective_pressure_brief(battle)
	if objective_brief != "":
		return objective_brief
	return "No battlefield objective is pulling harder than the line break."

static func _enemy_reply_line(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var reply_stack = _next_enemy_reply_stack(battle)
	if reply_stack.is_empty():
		return "No hostile stack remains to answer the next order."
	var action = BattleAiRulesScript.choose_enemy_action(
		battle,
		reply_stack,
		battle.get("enemy_hero", {})
	)
	return _enemy_action_preview_summary(battle, reply_stack, action)

static func _next_enemy_reply_stack(battle: Dictionary) -> Dictionary:
	var turn_order = battle.get("turn_order", [])
	if turn_order is Array:
		for index in range(int(battle.get("turn_index", 0)) + 1, turn_order.size()):
			var stack = _get_stack_by_id(battle, String(turn_order[index]))
			if not stack.is_empty() and _alive_count(stack) > 0 and String(stack.get("side", "")) == "enemy":
				return stack
	for stack in _alive_stacks_for_side(battle, "enemy"):
		if stack is Dictionary:
			return stack
	return {}

static func _enemy_action_preview_summary(battle: Dictionary, enemy_stack: Dictionary, action: Dictionary) -> String:
	if enemy_stack.is_empty():
		return "Hostile reply is unclear."
	var action_id = String(action.get("action", ""))
	var target = _get_stack_by_id(battle, String(action.get("target_battle_id", "")))
	match action_id:
		"cast_spell":
			var spell = ContentService.get_spell(String(action.get("spell_id", "")))
			return "%s is best placed to cast %s%s." % [
				_stack_label(enemy_stack),
				String(spell.get("name", "a spell")),
				" on %s" % _stack_label(target) if not target.is_empty() else "",
			]
		"shoot":
			return "%s is best placed to fire into %s." % [
				_stack_label(enemy_stack),
				_stack_label(target) if not target.is_empty() else "the exposed line",
			]
		"strike":
			return "%s is set to strike %s in the next exchange." % [
				_stack_label(enemy_stack),
				_stack_label(target) if not target.is_empty() else "the front rank",
			]
		"advance":
			return "%s is set to close the distance and press the lane." % _stack_label(enemy_stack)
		"defend":
			return "%s is set to hold and steady the hostile line." % _stack_label(enemy_stack)
	return "%s is best placed to keep pressure on the line." % _stack_label(enemy_stack)

static func _attack_action_summary(attacker: Dictionary, target: Dictionary, battle: Dictionary, is_ranged: bool) -> String:
	if attacker.is_empty() or target.is_empty():
		return "No clean target is lined up yet."
	var attack_distance = int(battle.get("distance", 1))
	var attack_preview = _damage_range_preview(attacker, target, battle, is_ranged, false, attack_distance)
	if attack_preview.is_empty():
		return "No clean target is lined up yet."
	var clauses = [
		"%s %s for %s" % [
			"Fire on" if is_ranged else "Hit",
			_stack_label(target),
			_damage_preview_text(attack_preview),
		],
	]
	if is_ranged:
		clauses.append("shots after volley %d" % max(0, int(attacker.get("shots_remaining", 0)) - 1))
		if _side_controls_field_objective_type(battle, String(target.get("side", "")), "cover_line") and attack_distance > 0:
			clauses.append("enemy cover will blunt part of the volley")
		elif _side_controls_field_objective_type(battle, String(attacker.get("side", "")), "cover_line") and attack_distance > 0:
			clauses.append("friendly cover keeps the firing angle cleaner")
	else:
		if int(target.get("retaliations_left", 0)) > 0 and _can_make_retaliation(target, attack_distance):
			var retaliation_preview = _retaliation_range_preview(attacker, target, battle, attack_distance, attack_preview)
			if not retaliation_preview.is_empty():
				clauses.append("expect %s retaliation" % _damage_preview_text(retaliation_preview))
		else:
			clauses.append("retaliation is spent or blocked")
	var objective_preview = _field_objective_action_preview(
		battle,
		{
			"action": "shoot" if is_ranged else "strike",
			"side": String(attacker.get("side", "")),
			"battle_id": String(attacker.get("battle_id", "")),
			"target_battle_id": String(target.get("battle_id", "")),
		}
	)
	if objective_preview != "":
		clauses.append(objective_preview)
	return "%s." % " | ".join(clauses)

static func _advance_action_summary(battle: Dictionary, stack: Dictionary) -> String:
	var distance = int(battle.get("distance", 1))
	if distance <= 0:
		return "The lines are already engaged."
	var next_distance = max(0, distance - 1)
	var clauses = [
		"Close from %s to %s" % [_distance_label(distance), _distance_label(next_distance)],
	]
	var momentum_gain = _preview_advance_momentum_gain(stack, battle)
	if momentum_gain > 0:
		clauses.append("momentum +%d" % momentum_gain)
	if _side_controls_field_objective_type(battle, _opposing_side(String(stack.get("side", ""))), "obstruction_line"):
		clauses.append("enemy obstruction will tax the push")
	elif _side_controls_field_objective_type(battle, _opposing_side(String(stack.get("side", ""))), "cover_line"):
		clauses.append("closing also strips hostile cover")
	if not bool(stack.get("ranged", false)) and next_distance <= 0:
		clauses.append("melee contact opens immediately")
	var objective_preview = _field_objective_action_preview(
		battle,
		{
			"action": "advance",
			"side": String(stack.get("side", "")),
			"battle_id": String(stack.get("battle_id", "")),
		}
	)
	if objective_preview != "":
		clauses.append(objective_preview)
	return "%s." % " | ".join(clauses)

static func _defend_action_summary(battle: Dictionary, stack: Dictionary) -> String:
	var clauses = ["Brace this stack for the next exchange"]
	var cohesion_gain = _preview_defend_cohesion_gain(stack, battle)
	if cohesion_gain > 0:
		clauses.append("cohesion +%d" % cohesion_gain)
	if int(stack.get("momentum", 0)) > 0:
		clauses.append("shed 1 momentum")
	if bool(stack.get("ranged", false)):
		clauses.append("protect the firing lane")
	elif int(stack.get("retaliations_left", 0)) > 0:
		clauses.append("retaliation stays live")
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "cover_line"):
		clauses.append("hold the screened cover line")
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "obstruction_line"):
		clauses.append("keep the obstruction sealed")
	if _has_ability(stack, "brace"):
		clauses.append("Brace can stagger the next attacker")
	elif _has_ability(stack, "formation_guard"):
		clauses.append("Formation Guard steadies nearby lanes")
	var objective_preview = _field_objective_action_preview(
		battle,
		{
			"action": "defend",
			"side": String(stack.get("side", "")),
			"battle_id": String(stack.get("battle_id", "")),
		}
	)
	if objective_preview != "":
		clauses.append(objective_preview)
	return "%s." % " | ".join(clauses)

static func _retreat_action_summary(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "No battle is active."
	var battle = session.battle
	if not bool(battle.get("retreat_allowed", true)):
		return "Retreat is locked while defending a town."
	var player_totals = _army_totals(battle, "player")
	var clauses = [
		"Break contact and preserve %d surviving stack%s from the field" % [
			int(player_totals.get("stacks", 0)),
			"" if int(player_totals.get("stacks", 0)) == 1 else "s",
		],
	]
	var preview := _build_withdrawal_aftermath_preview(session, "retreat")
	var aftermath_summary := _withdrawal_preview_summary(preview, "retreat")
	if aftermath_summary != "":
		clauses.append(aftermath_summary)
	return "%s." % " | ".join(clauses)

static func _surrender_action_summary(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "No battle is active."
	if not bool(session.battle.get("surrender_allowed", true)):
		return "Surrender is locked while defending a town."
	var player_totals = _army_totals(session.battle, "player")
	var clauses = [
		"Yield the field and preserve %d surviving stack%s under surrender terms" % [
			int(player_totals.get("stacks", 0)),
			"" if int(player_totals.get("stacks", 0)) == 1 else "s",
		],
	]
	var preview := _build_withdrawal_aftermath_preview(session, "surrender")
	var aftermath_summary := _withdrawal_preview_summary(preview, "surrender")
	if aftermath_summary != "":
		clauses.append(aftermath_summary)
	return "%s." % " | ".join(clauses)

static func _build_withdrawal_aftermath_preview(
	session: SessionStateStoreScript.SessionData,
	outcome: String
) -> Dictionary:
	var preview := {
		"enemy_faction_id": "",
		"enemy_label": "The opposing host",
		"resource_loss": {},
		"casualty_units": 0,
		"pressure_delta": 0,
		"nearest_town_placement_id": "",
		"nearest_town_name": "",
		"recovery_pressure": 0,
	}
	if session == null or session.battle.is_empty():
		return preview

	var enemy_faction_id := _battle_enemy_faction_id(session)
	preview["enemy_faction_id"] = enemy_faction_id
	preview["enemy_label"] = _battle_enemy_label(session, enemy_faction_id)

	var commander_source = session.battle.get("player_commander_source", {})
	var hero_id := String(commander_source.get("hero_id", session.overworld.get("active_hero_id", "")))
	var player_survivors := _battle_survivor_stacks(
		session,
		"player",
		{
			"source_type": "hero_army",
			"hero_id": hero_id,
		}
	)
	if player_survivors.is_empty():
		player_survivors = _battle_survivor_stacks(session, "player")
	var enemy_survivors := _battle_survivor_stacks(
		session,
		"enemy",
		{
			"source_type": "encounter_army",
			"encounter_key": String(session.battle.get("resolved_key", "")),
		}
	)
	if enemy_survivors.is_empty():
		enemy_survivors = _battle_survivor_stacks(session, "enemy")

	var player_units: int = _stack_count_total(player_survivors)
	var player_strength: int = _army_strength_from_stacks(player_survivors)
	var enemy_strength: int = _army_strength_from_stacks(enemy_survivors)
	var severity: int = clampi(1 + int(floor(float(enemy_strength) / float(max(1, player_strength)))), 1, 4)
	var desired_loss: Dictionary = {"gold": 0, "wood": 0, "ore": 0}

	match outcome:
		"surrender":
			desired_loss["gold"] = 180 + (severity * 90) + int(round(float(enemy_strength) / 12.0))
			desired_loss["wood"] = max(0, severity - 1)
			desired_loss["ore"] = 1 if severity >= 3 else 0
			preview["casualty_units"] = _casualty_units_from_ratio(player_units, 0.04 + (float(severity) * 0.03))
			preview["pressure_delta"] = 1 + (1 if enemy_faction_id != "" and severity >= 4 else 0) if enemy_faction_id != "" else 0
			preview["recovery_pressure"] = 1
		_:
			desired_loss["gold"] = 90 + (severity * 70) + int(round(float(enemy_strength) / 18.0))
			desired_loss["wood"] = max(0, severity - 1)
			desired_loss["ore"] = 1 if severity >= 4 else 0
			preview["casualty_units"] = _casualty_units_from_ratio(player_units, 0.12 + (float(severity) * 0.06))
			preview["pressure_delta"] = 1 + int(severity / 2) if enemy_faction_id != "" else 0
			preview["recovery_pressure"] = 1 + (1 if severity >= 3 else 0)

	preview["resource_loss"] = _clamped_resource_loss(session, desired_loss)
	var battle_position = session.battle.get("position", {})
	var nearest_town_result = OverworldRulesScript._nearest_town_for_controller(
		session,
		"player",
		int(battle_position.get("x", 0)),
		int(battle_position.get("y", 0))
	)
	if int(nearest_town_result.get("index", -1)) >= 0:
		var town = nearest_town_result.get("town", {})
		preview["nearest_town_placement_id"] = String(town.get("placement_id", ""))
		preview["nearest_town_name"] = _town_name(town)
	return preview

static func _withdrawal_preview_summary(preview: Dictionary, outcome: String) -> String:
	var clauses := []
	var casualty_units = int(preview.get("casualty_units", 0))
	if casualty_units > 0:
		clauses.append(
			"about %d troop%s %s" % [
				casualty_units,
				"" if casualty_units == 1 else "s",
				"lost while the enemy collects the terms" if outcome == "surrender" else "lost to the pursuit",
			]
		)
	var resource_loss = preview.get("resource_loss", {})
	var resource_summary = OverworldRulesScript._describe_resource_delta(resource_loss)
	if resource_summary != "":
		if outcome == "surrender":
			clauses.append("pay %s to the enemy" % resource_summary)
		else:
			clauses.append("abandon %s to the enemy" % resource_summary)
	var pressure_delta = int(preview.get("pressure_delta", 0))
	var enemy_label := String(preview.get("enemy_label", "Enemy pressure"))
	if pressure_delta > 0:
		clauses.append("%s pressure +%d" % [enemy_label, pressure_delta])
	elif int(preview.get("recovery_pressure", 0)) > 0 and String(preview.get("nearest_town_name", "")) != "":
		clauses.append("%s recovery +%d" % [
			String(preview.get("nearest_town_name", "")),
			int(preview.get("recovery_pressure", 0)),
		])
	return " | ".join(clauses)

static func _casualty_units_from_ratio(total_units: int, ratio: float) -> int:
	if total_units <= 1:
		return 0
	var casualties = int(round(float(total_units) * clampf(ratio, 0.0, 0.9)))
	if casualties <= 0 and total_units >= 5 and ratio >= 0.12:
		casualties = 1
	return clamp(casualties, 0, total_units - 1)

static func _clamped_resource_loss(session: SessionStateStoreScript.SessionData, desired_loss: Dictionary) -> Dictionary:
	var available = session.overworld.get("resources", {})
	var loss := {}
	for resource_key in ["gold", "wood", "ore"]:
		var amount = min(max(0, int(desired_loss.get(resource_key, 0))), max(0, int(available.get(resource_key, 0))))
		if amount > 0:
			loss[resource_key] = amount
	return loss

static func _battle_enemy_faction_id(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return ""
	var context = session.battle.get("context", {})
	var faction_id := ""
	if _is_town_defense_context(context) or _is_town_assault_context(context):
		faction_id = String(context.get("trigger_faction_id", ""))
		if _enemy_state_exists(session, faction_id):
			return faction_id
	var encounter = _current_battle_encounter_placement(session)
	faction_id = String(encounter.get("spawned_by_faction_id", ""))
	if _enemy_state_exists(session, faction_id):
		return faction_id
	faction_id = _side_faction_id(session.battle, "enemy")
	return faction_id if _enemy_state_exists(session, faction_id) else ""

static func _enemy_state_exists(session: SessionStateStoreScript.SessionData, faction_id: String) -> bool:
	if session == null or faction_id == "":
		return false
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return true
	return false

static func _battle_enemy_label(session: SessionStateStoreScript.SessionData, faction_id: String) -> String:
	if faction_id != "":
		return String(ContentService.get_faction(faction_id).get("name", faction_id))
	if session == null or session.battle.is_empty():
		return "The opposing host"
	return String(session.battle.get("encounter_name", session.battle.get("encounter_id", "The opposing host")))

static func _stack_count_total(stacks: Variant) -> int:
	var total := 0
	if not (stacks is Array):
		return total
	for stack in stacks:
		if stack is Dictionary:
			total += max(0, int(stack.get("count", 0)))
	return total

static func _preview_advance_momentum_gain(stack: Dictionary, battle: Dictionary) -> int:
	if stack.is_empty():
		return 0
	var momentum_gain = 1 if not bool(stack.get("ranged", false)) else 0
	if _hero_has_trait(battle, String(stack.get("side", "")), "vanguard") and not bool(stack.get("ranged", false)):
		momentum_gain += 1
	if _hero_has_trait(battle, String(stack.get("side", "")), "ambusher") and _battle_has_any_tags(battle, ["ambush_cover"]) and not bool(stack.get("ranged", false)):
		momentum_gain += 1
	if _battle_has_tag(battle, "open_lane") and (not bool(stack.get("ranged", false)) or _hero_has_trait(battle, String(stack.get("side", "")), "artillerist")):
		momentum_gain += 1
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "obstruction_line") and not bool(stack.get("ranged", false)):
		momentum_gain += 1
	if _side_controls_field_objective_type(battle, _opposing_side(String(stack.get("side", ""))), "obstruction_line"):
		momentum_gain -= 1
	return max(0, momentum_gain)

static func _preview_defend_cohesion_gain(stack: Dictionary, battle: Dictionary) -> int:
	if stack.is_empty():
		return 0
	var cohesion_gain = 1
	var brace = _ability_by_id(stack, "brace")
	if not brace.is_empty():
		cohesion_gain += max(0, int(brace.get("defending_cohesion_bonus", 0)))
	var formation_guard = _ability_by_id(stack, "formation_guard")
	if not formation_guard.is_empty():
		cohesion_gain += max(0, int(formation_guard.get("defending_cohesion_bonus", 0)))
	if _hero_has_trait(battle, String(stack.get("side", "")), "linekeeper"):
		cohesion_gain += 1
	if _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not bool(stack.get("ranged", false)):
		cohesion_gain += 1
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "cover_line"):
		cohesion_gain += 1
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "obstruction_line") and not bool(stack.get("ranged", false)):
		cohesion_gain += 1
	return max(0, cohesion_gain)

static func _active_ability_window_summary(stack: Dictionary, battle: Dictionary, target: Dictionary) -> String:
	if stack.is_empty():
		return ""
	var distance = int(battle.get("distance", 1))
	if _has_ability(stack, "reach") and not bool(stack.get("ranged", false)) and distance == 1:
		return "Reach makes melee contact live from the current closing distance."
	if _has_ability(stack, "volley") and bool(stack.get("ranged", false)) and distance >= int(_ability_by_id(stack, "volley").get("min_distance", 1)):
		return "Volley rewards the long lane while the firing line stays open."
	if _has_ability(stack, "harry") and bool(stack.get("ranged", false)):
		return "Harry will mark the target and soften its defense tempo for later breaks."
	if _has_ability(stack, "brace") and int(stack.get("retaliations_left", 0)) > 0:
		return "Brace can stagger the next attacker if this stack holds."
	if _has_ability(stack, "formation_guard"):
		return "Formation Guard is live if this stack steadies the line and keeps allies covered."
	if not target.is_empty() and _has_ability(stack, "backstab") and (
		SpellRulesScript.has_any_effect_ids(target, battle, _ability_by_id(stack, "backstab").get("status_ids", []))
		or _health_ratio(target) <= float(_ability_by_id(stack, "backstab").get("health_threshold_ratio", 0.0))
	):
		return "Backstab is live on the marked target right now."
	if not target.is_empty() and _has_ability(stack, "bloodrush") and _health_ratio(target) <= float(_ability_by_id(stack, "bloodrush").get("wounded_threshold_ratio", 0.0)):
		return "Bloodrush is live on the wounded target and can snowball momentum."
	if not target.is_empty() and _has_ability(stack, "shielding") and SpellRulesScript.has_effect_id(target, battle, STATUS_HARRIED):
		return "Shielding bites harder into a harried target once the line closes."
	var ability_summary = _stack_ability_summary(stack)
	return "Abilities in hand: %s." % ability_summary if ability_summary != "" else ""

static func _field_objective_action_preview(battle: Dictionary, action_context: Dictionary) -> String:
	var acting_side = String(action_context.get("side", ""))
	if acting_side not in ["player", "enemy"]:
		return ""
	var acting_stack = _get_stack_by_id(battle, String(action_context.get("battle_id", "")))
	var target_stack = _get_stack_by_id(battle, String(action_context.get("target_battle_id", "")))
	var notes = []
	for objective in _field_objectives(battle):
		if not (objective is Dictionary):
			continue
		var influence = _field_objective_action_influence(objective, battle, acting_side, action_context, acting_stack, target_stack)
		if influence <= 0:
			continue
		var projection = _project_field_objective_state(objective, acting_side, influence)
		var label = _field_objective_label(objective)
		if bool(projection.get("flipped", false)):
			notes.append("%s would swing to %s control" % [label, _side_label(acting_side)])
			continue
		if String(objective.get("control_side", "neutral")) == acting_side:
			notes.append("%s hold strengthens" % label)
			continue
		var progress_side = String(projection.get("progress_side", ""))
		var progress_value = int(projection.get("progress_value", 0))
		var threshold = int(projection.get("capture_threshold", objective.get("capture_threshold", 2)))
		if progress_side == acting_side and progress_value > 0:
			notes.append("%s moves to %d/%d toward %s control" % [label, progress_value, threshold, _side_label(acting_side)])
		if notes.size() >= 2:
			break
	return "; ".join(notes)

static func _project_field_objective_state(objective: Dictionary, acting_side: String, amount: int) -> Dictionary:
	var projection = objective.duplicate(true)
	var controller = String(projection.get("control_side", "neutral"))
	var progress_side = String(projection.get("progress_side", ""))
	var progress_value = max(0, int(projection.get("progress_value", 0)))
	var threshold = max(1, int(projection.get("capture_threshold", 2)))
	var flipped = false
	if controller == acting_side:
		if progress_side != "" and progress_side != acting_side:
			progress_value = max(0, progress_value - amount)
			if progress_value <= 0:
				progress_side = ""
	else:
		if progress_side != "" and progress_side != acting_side:
			progress_value = max(0, progress_value - amount)
			if progress_value <= 0:
				progress_side = acting_side
				progress_value = amount
		else:
			progress_side = acting_side
			progress_value += amount
		if progress_value >= threshold:
			controller = acting_side
			progress_side = ""
			progress_value = 0
			flipped = true
	projection["control_side"] = controller
	projection["progress_side"] = progress_side
	projection["progress_value"] = progress_value if progress_side != "" else 0
	projection["capture_threshold"] = threshold
	projection["flipped"] = flipped
	return projection

static func _should_surface_tactical_briefing(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null or session.battle.is_empty():
		return false
	if session.scenario_status != "in_progress":
		return false
	if int(session.battle.get("round", 1)) != 1:
		return false
	var briefing_state = session.battle.get(TACTICAL_BRIEFING_KEY, {})
	return briefing_state is Dictionary and not bool(briefing_state.get("shown", false))

static func _tactical_briefing_lines(session: SessionStateStoreScript.SessionData) -> Array:
	var battle = session.battle
	var scenario = ContentService.get_scenario(session.scenario_id)
	var lines = []
	var battlefield_line = _tactical_battlefield_line(session, battle)
	if battlefield_line != "":
		lines.append(battlefield_line)
	var objective_line = _tactical_objective_line(session, battle, scenario)
	if objective_line != "":
		lines.append(objective_line)
	var field_objective_line = _tactical_field_objective_line(battle)
	if field_objective_line != "":
		lines.append(field_objective_line)
	var doctrine_line = _tactical_enemy_doctrine_line(battle)
	if doctrine_line != "":
		lines.append(doctrine_line)
	var pressure_line = _tactical_opening_pressure_line(session, battle)
	if pressure_line != "":
		lines.append(pressure_line)
	var decisive_line = _tactical_decisive_target_line(battle)
	if decisive_line != "":
		lines.append(decisive_line)
	var caution_line = _tactical_caution_line(session, battle)
	if caution_line != "":
		lines.append(caution_line)
	return lines

static func _tactical_battlefield_line(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var parts = [
		String(battle.get("terrain", "plains")).capitalize(),
		_distance_label(int(battle.get("distance", 1))),
	]
	var identity_summary = _battlefield_identity_summary(battle)
	if identity_summary != "":
		parts.append(identity_summary)
	var tag_labels = _battlefield_tag_labels(battle)
	if not tag_labels.is_empty():
		parts.append("Tags %s" % ", ".join(tag_labels))
	if _is_town_defense_context(battle.get("context", {})) or _is_town_assault_context(battle.get("context", {})):
		parts.append(_battle_context_label(session, battle.get("context", {})))
	return "Battlefield: %s" % " | ".join(parts)

static func _tactical_objective_line(session: SessionStateStoreScript.SessionData, battle: Dictionary, scenario: Dictionary) -> String:
	if _is_town_defense_context(battle.get("context", {})):
		var town_name = _town_name_from_placement_id(session, String(battle.get("context", {}).get("town_placement_id", "")))
		return "Battle aim: Hold %s. A collapse here loses the town and cedes the lane." % (
			town_name if town_name != "" else "the walls"
		)
	if _is_town_assault_context(battle.get("context", {})):
		var assault_town_name = _town_name_from_placement_id(session, String(battle.get("context", {}).get("town_placement_id", "")))
		return "Battle aim: Take %s. Breaking the garrison opens the town and collapses this hostile anchor." % (
			assault_town_name if assault_town_name != "" else "the walls"
		)
	var encounter_objective = _encounter_objective_for_battle(session, battle, scenario)
	if not encounter_objective.is_empty():
		return "Battle aim: %s" % ScenarioRulesScript._objective_label(session, encounter_objective)
	var objectives = scenario.get("objectives", {})
	if objectives is Dictionary:
		var victory_labels = ScenarioRulesScript._objective_labels_from_bucket(session, objectives.get("victory", []), 1)
		if not victory_labels.is_empty():
			return "Battle aim: %s" % String(victory_labels[0])
	return ""

static func _tactical_field_objective_line(battle: Dictionary) -> String:
	var objective_summary = _field_objective_pressure_summary(battle)
	return "Battlefield objective: %s" % objective_summary if objective_summary != "" else ""

static func _tactical_enemy_doctrine_line(battle: Dictionary) -> String:
	var commander_state = _commander_state_for_side(battle, "enemy")
	var doctrine = _side_doctrine_summary(battle, "enemy")
	var commander_name = String(commander_state.get("name", "Enemy command"))
	var trait_labels = _battle_trait_labels(_normalized_battle_traits(commander_state))
	var parts = ["%s | %s" % [commander_name, doctrine]]
	if not trait_labels.is_empty():
		parts.append("Traits %s" % ", ".join(trait_labels))
	return "Enemy doctrine: %s" % " | ".join(parts)

static func _tactical_opening_pressure_line(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var player_totals = _army_totals(battle, "player")
	var enemy_totals = _army_totals(battle, "enemy")
	return "Opening pressure: %s | Friendly ranged %d | Enemy ranged %d | Retreat %s" % [
		_pressure_brief(session),
		int(player_totals.get("ranged_stacks", 0)),
		int(enemy_totals.get("ranged_stacks", 0)),
		"Open" if bool(battle.get("retreat_allowed", true)) else "Locked",
	]

static func _tactical_decisive_target_line(battle: Dictionary) -> String:
	var target = _priority_enemy_stack_for_briefing(battle)
	if target.is_empty():
		return ""
	return "Decisive target: %s | %s" % [
		_stack_label(target),
		_priority_target_reason(target, battle),
	]

static func _tactical_caution_line(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	if _battle_has_tag(battle, "battery_nest") and int(battle.get("distance", 1)) > 0:
		return "Tactical caution: The approach stays exposed while battery lanes are open; trade shots only if you can win the ranged exchange."
	if _side_controls_field_objective_type(battle, "enemy", "cover_line") and int(battle.get("distance", 1)) > 0:
		return "Tactical caution: Enemy cover still screens the firing line and commander; dislodge it before settling into a long volley."
	if _side_controls_field_objective_type(battle, "enemy", "obstruction_line") and int(battle.get("distance", 1)) > 0:
		return "Tactical caution: The obstruction line is still taxing the push. Lead with the toughest breach stack."
	if _battle_has_tag(battle, "fortress_lane"):
		return "Tactical caution: Fortress lanes compress melee into a kill zone. Brace anchors before committing the full assault."
	if _battle_has_tag(battle, "wall_pressure") and int(battle.get("round", 1)) <= 2:
		return "Tactical caution: Delay the breach now and the enemy's late melee pressure will spike after round three."
	var player_totals = _army_totals(battle, "player")
	var enemy_totals = _army_totals(battle, "enemy")
	if int(enemy_totals.get("ranged_stacks", 0)) > int(player_totals.get("ranged_stacks", 0)) and int(battle.get("distance", 1)) > 0:
		return "Tactical caution: Enemy shooting outranges your opening line; close distance with the toughest stacks first."
	if int(player_totals.get("ranged_stacks", 0)) > int(enemy_totals.get("ranged_stacks", 0)) and int(battle.get("distance", 1)) > 0:
		return "Tactical edge: You own the cleaner firing line. Spend the opening volleys before the lines fully engage."
	if _is_town_defense_context(battle.get("context", {})):
		return "Tactical caution: Retreat is locked on the walls. Preserve disciplined defenders and trade for position, not speed."
	if _is_town_assault_context(battle.get("context", {})):
		return "Tactical caution: If the breach stalls, the town stays hostile. Keep pressure on the wall lane and decisive stacks."
	return ""

static func _risk_readiness_grade(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var severity = 0
	var stability = 0
	var player_totals = _army_totals(battle, "player")
	var enemy_totals = _army_totals(battle, "enemy")
	var player_health = int(player_totals.get("health", 0))
	var enemy_health = int(enemy_totals.get("health", 0))
	var player_wavering = _wavering_stack_count(battle, "player")
	var enemy_wavering = _wavering_stack_count(battle, "enemy")
	var player_steady = _steady_stack_count(battle, "player")
	var next_window = _next_activation_window(battle, 3)
	var player_next = 0
	var enemy_next = 0
	for stack in next_window:
		if String(stack.get("side", "")) == "player":
			player_next += 1
		else:
			enemy_next += 1
	if enemy_next >= 2 and enemy_next > player_next:
		severity += 2
	elif player_next >= 2 and player_next > enemy_next:
		stability += 2
	if player_wavering >= 2:
		severity += 2
	elif player_wavering == 1:
		severity += 1
	if enemy_wavering >= 2:
		stability += 2
	elif enemy_wavering == 1:
		stability += 1
	if player_steady <= 1:
		severity += 1
	elif player_steady >= 3:
		stability += 1
	if player_health > 0 and enemy_health > int(round(float(player_health) * 1.25)):
		severity += 2
	elif enemy_health > 0 and player_health > int(round(float(enemy_health) * 1.25)):
		stability += 2
	if _average_side_cohesion(battle, "player") >= 7.0:
		stability += 1
	if _average_side_cohesion(battle, "player") <= 5.0:
		severity += 1
	if int(battle.get("distance", 1)) > 0:
		var player_shots = _side_shots_remaining(battle, "player")
		var enemy_shots = _side_shots_remaining(battle, "enemy")
		if enemy_shots > player_shots:
			severity += 1
		elif player_shots > enemy_shots:
			stability += 1
	if not bool(battle.get("retreat_allowed", true)):
		severity += 1
	if max(0, int(battle.get("max_rounds", 12)) - int(battle.get("round", 1)) + 1) <= 2:
		severity += 1
	var category = "Balanced posture."
	if stability >= 5 and severity <= 1:
		category = "Strong stabilization posture."
	elif stability >= 3 and severity <= 2:
		category = "Ready pressure posture."
	elif severity >= 6:
		category = "Collapse risk rising."
	elif severity >= 4:
		category = "Fragile exchange."
	elif severity >= 2:
		category = "Contested posture."
	return "%s %s" % [category, _pressure_brief(session)]

static func _risk_board_initiative_line(battle: Dictionary) -> String:
	var next_window = _next_activation_window(battle, 3)
	if next_window.is_empty():
		return "the turn order is rebuilding after a collapse."
	var player_count = 0
	var enemy_count = 0
	for stack in next_window:
		if String(stack.get("side", "")) == "player":
			player_count += 1
		else:
			enemy_count += 1
	var first_stack = next_window[0]
	var window_size = next_window.size()
	if player_count > enemy_count:
		return "friendly line controls %d of the next %d activations, starting with %s at Init %d." % [
			player_count,
			window_size,
			_stack_label(first_stack),
			_stack_initiative_total(first_stack, battle),
		]
	if enemy_count > player_count:
		return "enemy line controls %d of the next %d activations, starting with %s at Init %d." % [
			enemy_count,
			window_size,
			_stack_label(first_stack),
			_stack_initiative_total(first_stack, battle),
		]
	return "the next %d activations are split evenly, with %s acting first at Init %d." % [
		window_size,
		_stack_label(first_stack),
		_stack_initiative_total(first_stack, battle),
	]

static func _risk_board_commander_line(battle: Dictionary) -> String:
	var commander_state = _commander_state_for_side(battle, "player")
	var commander_payload = _hero_payload_for_side(battle, "player")
	var enemy_payload = _hero_payload_for_side(battle, "enemy")
	var commander_name = String(commander_state.get("name", "Field command"))
	var steady_count = _steady_stack_count(battle, "player")
	var wavering_count = _wavering_stack_count(battle, "player")
	var initiative_edge = int(commander_payload.get("initiative", 0)) - int(enemy_payload.get("initiative", 0))
	var aura_summary = "aura even with enemy command"
	if initiative_edge > 0:
		aura_summary = "aura leads enemy command by %d initiative" % initiative_edge
	elif initiative_edge < 0:
		aura_summary = "aura trails enemy command by %d initiative" % abs(initiative_edge)
	var cover_summary = "line covered"
	var command_screen = 0
	if _side_controls_field_objective_type(battle, "player", "cover_line"):
		command_screen += 2
	if _side_controls_field_objective_type(battle, "player", "signal_beacon"):
		command_screen += 1
	if _side_controls_field_objective_type(battle, "enemy", "cover_line"):
		command_screen -= 1
	if _side_controls_field_objective_type(battle, "enemy", "signal_beacon"):
		command_screen -= 1
	if _side_controls_field_objective_type(battle, "enemy", "obstruction_line") and int(battle.get("distance", 1)) > 0:
		command_screen -= 1
	if command_screen >= 2:
		cover_summary = "command screened"
	elif steady_count <= 1 and wavering_count >= 2:
		cover_summary = "command exposed"
	elif wavering_count > 0:
		cover_summary = "cover contested"
	return "%s | Mana %d/%d | %d steady, %d wavering | %s | %s." % [
		commander_name,
		int(commander_payload.get("mana_current", 0)),
		int(commander_payload.get("mana_max", 0)),
		steady_count,
		wavering_count,
		cover_summary,
		aura_summary,
	]

static func _risk_board_line_integrity_line(battle: Dictionary) -> String:
	var player_wavering = _wavering_stack_count(battle, "player")
	var enemy_wavering = _wavering_stack_count(battle, "enemy")
	var player_average = _average_side_cohesion(battle, "player")
	var enemy_average = _average_side_cohesion(battle, "enemy")
	if player_wavering > 0 and (player_wavering >= enemy_wavering or player_average < enemy_average):
		var weakest_player = _weakest_stack_by_cohesion(battle, "player")
		return "%d friendly stack%s are wavering at low cohesion; %s is the softest point." % [
			player_wavering,
			"" if player_wavering == 1 else "s",
			_stack_label(weakest_player),
		]
	if enemy_wavering > 0:
		var weakest_enemy = _weakest_stack_by_cohesion(battle, "enemy")
		return "%d enemy stack%s are wavering at low cohesion; %s is ready to break." % [
			enemy_wavering,
			"" if enemy_wavering == 1 else "s",
			_stack_label(weakest_enemy),
		]
	if player_average >= 7.0 and _side_defending_count(battle, "player") > 0:
		return "friendly anchors are stabilized at %.1f average cohesion with %d defending stacks." % [
			player_average,
			_side_defending_count(battle, "player"),
		]
	return "average cohesion is %.1f friendly to %.1f enemy, so the line has not cracked yet." % [
		player_average,
		enemy_average,
	]

static func _risk_board_ranged_pressure_line(battle: Dictionary) -> String:
	var player_totals = _army_totals(battle, "player")
	var enemy_totals = _army_totals(battle, "enemy")
	var player_ranged = int(player_totals.get("ranged_stacks", 0))
	var enemy_ranged = int(enemy_totals.get("ranged_stacks", 0))
	var player_shots = _side_shots_remaining(battle, "player")
	var enemy_shots = _side_shots_remaining(battle, "enemy")
	var lane_label = _risk_board_lane_label(battle)
	if max(player_ranged, enemy_ranged) <= 0:
		return "no ranged pressure remains; melee tempo will decide the exchange."
	if int(battle.get("distance", 1)) <= 0:
		if enemy_ranged > player_ranged:
			return "%d enemy ranged stack%s still threaten from behind the melee." % [
				enemy_ranged,
				"" if enemy_ranged == 1 else "s",
			]
		if player_ranged > enemy_ranged:
			return "your %d ranged stack%s still have protected rear angles." % [
				player_ranged,
				"" if player_ranged == 1 else "s",
			]
		return "the lines are engaged, so surviving shooters now depend on protected rear lanes."
	if enemy_shots > player_shots:
		var enemy_lane = "covered %s" % lane_label if _side_controls_field_objective_type(battle, "enemy", "cover_line") else lane_label
		return "enemy batteries own the %s with %d stack%s and %d shots remaining." % [
			enemy_lane,
			enemy_ranged,
			"" if enemy_ranged == 1 else "s",
			enemy_shots,
		]
	if player_shots > enemy_shots:
		var player_lane = "covered %s" % lane_label if _side_controls_field_objective_type(battle, "player", "cover_line") else lane_label
		return "friendly batteries own the %s with %d stack%s and %d shots remaining." % [
			player_lane,
			player_ranged,
			"" if player_ranged == 1 else "s",
			player_shots,
		]
	if _side_controls_field_objective_type(battle, "enemy", "obstruction_line"):
		return "enemy obstructions are keeping the %s narrow even on even shots." % lane_label
	if _side_controls_field_objective_type(battle, "player", "obstruction_line"):
		return "friendly hands own the %s choke and can blunt the next enemy volley." % lane_label
	if enemy_ranged > player_ranged:
		return "enemy line holds the deeper firing stack count even on equal shots."
	if player_ranged > enemy_ranged:
		return "friendly line holds the deeper firing stack count if the lane stays open."
	return "ranged pressure is even across the %s." % lane_label

static func _risk_board_priority_line(battle: Dictionary) -> String:
	var decisive_target = _priority_enemy_stack_for_briefing(battle)
	if decisive_target.is_empty():
		return "no decisive target is exposed yet."
	var selected_target = get_selected_target(battle)
	if not selected_target.is_empty() and String(selected_target.get("battle_id", "")) == String(decisive_target.get("battle_id", "")):
		return "%s is already marked; %s." % [
			_stack_label(decisive_target),
			_priority_target_reason(decisive_target, battle),
		]
	return "shift focus to %s; %s." % [
		_stack_label(decisive_target),
		_priority_target_reason(decisive_target, battle),
	]

static func _risk_board_objective_line(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var summary = _field_objective_urgency_summary(session, battle)
	return summary if summary != "" else "break the opposing line before the clock turns."

static func _risk_board_dispatch_line(battle: Dictionary) -> String:
	for event_text in battle.get("recent_events", []):
		var line = String(event_text).strip_edges()
		if line != "":
			return line
	return ""

static func _next_activation_window(battle: Dictionary, count: int) -> Array:
	var window = []
	var turn_order = battle.get("turn_order", [])
	if not (turn_order is Array):
		return window
	for index in range(max(0, int(battle.get("turn_index", 0))), turn_order.size()):
		var stack = _get_stack_by_id(battle, String(turn_order[index]))
		if stack.is_empty() or _alive_count(stack) <= 0:
			continue
		window.append(stack)
		if window.size() >= count:
			break
	return window

static func _steady_stack_count(battle: Dictionary, side: String) -> int:
	var total = 0
	for stack in _alive_stacks_for_side(battle, side):
		if _stack_cohesion_total(stack, battle) >= 6 and not _stack_is_isolated(battle, stack):
			total += 1
	return total

static func _wavering_stack_count(battle: Dictionary, side: String) -> int:
	var total = 0
	for stack in _alive_stacks_for_side(battle, side):
		if _stack_cohesion_total(stack, battle) <= 4 or _stack_is_isolated(battle, stack) or SpellRulesScript.has_any_effect_ids(stack, battle, [STATUS_STAGGERED, STATUS_HARRIED]):
			total += 1
	return total

static func _average_side_cohesion(battle: Dictionary, side: String) -> float:
	var stacks = _alive_stacks_for_side(battle, side)
	if stacks.is_empty():
		return 0.0
	var total = 0.0
	for stack in stacks:
		total += float(_stack_cohesion_total(stack, battle))
	return total / float(stacks.size())

static func _weakest_stack_by_cohesion(battle: Dictionary, side: String) -> Dictionary:
	var weakest = {}
	var weakest_score = 99999
	for stack in _alive_stacks_for_side(battle, side):
		var score = _stack_cohesion_total(stack, battle)
		if _stack_is_isolated(battle, stack):
			score -= 1
		if SpellRulesScript.has_any_effect_ids(stack, battle, [STATUS_STAGGERED, STATUS_HARRIED]):
			score -= 1
		if weakest.is_empty() or score < weakest_score:
			weakest = stack
			weakest_score = score
	return weakest

static func _weakest_stack_by_role(battle: Dictionary, side: String, prefer_ranged: bool) -> Dictionary:
	var weakest = {}
	var weakest_score = 99999
	for stack in _alive_stacks_for_side(battle, side):
		if bool(stack.get("ranged", false)) != prefer_ranged:
			continue
		var score = _stack_cohesion_total(stack, battle)
		if _stack_is_isolated(battle, stack):
			score -= 1
		if SpellRulesScript.has_any_effect_ids(stack, battle, [STATUS_STAGGERED, STATUS_HARRIED]):
			score -= 1
		if weakest.is_empty() or score < weakest_score:
			weakest = stack
			weakest_score = score
	if weakest.is_empty():
		return _weakest_stack_by_cohesion(battle, side)
	return weakest

static func _side_shots_remaining(battle: Dictionary, side: String) -> int:
	var total = 0
	for stack in _alive_stacks_for_side(battle, side):
		if bool(stack.get("ranged", false)):
			total += max(0, int(stack.get("shots_remaining", 0)))
	return total

static func _risk_board_lane_label(battle: Dictionary) -> String:
	if _battle_has_tag(battle, "battery_nest"):
		return "battery lane"
	if _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
		return "fire lane"
	return _distance_label(int(battle.get("distance", 1))).to_lower()

static func _battlefield_tag_labels(battle: Dictionary) -> Array:
	var labels = []
	for tag_value in battle.get("battlefield_tags", []):
		var label = _titleize_token(String(tag_value))
		if label != "" and label not in labels:
			labels.append(label)
		if labels.size() >= 4:
			break
	return labels

static func _battle_trait_labels(traits: Array) -> Array:
	var labels = []
	for trait_value in traits:
		var label = _titleize_token(String(trait_value))
		if label != "" and label not in labels:
			labels.append(label)
		if labels.size() >= 3:
			break
	return labels

static func _encounter_objective_for_battle(session: SessionStateStoreScript.SessionData, battle: Dictionary, scenario: Dictionary) -> Dictionary:
	if scenario.is_empty():
		return {}
	var encounter_placement = _current_battle_encounter_placement(session)
	var placement_id = String(encounter_placement.get("placement_id", battle.get("resolved_key", "")))
	if placement_id == "":
		return {}
	var objectives = scenario.get("objectives", {})
	if not (objectives is Dictionary):
		return {}
	for bucket_name in ["victory", "defeat"]:
		for objective in objectives.get(bucket_name, []):
			if objective is Dictionary and String(objective.get("type", "")) == "encounter_resolved" and String(objective.get("placement_id", "")) == placement_id:
				return objective
	return {}

static func _current_battle_encounter_placement(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {}
	return _find_encounter_by_key(session, String(session.battle.get("resolved_key", ""))).get("encounter", {})

static func _priority_enemy_stack_for_briefing(battle: Dictionary) -> Dictionary:
	var best = {}
	var best_score = -99999
	for stack in _alive_stacks_for_side(battle, "enemy"):
		var score = 0
		if bool(stack.get("ranged", false)):
			score += 5 if _battle_has_any_tags(battle, ["battery_nest", "elevated_fire", "open_lane"]) else 3
			if _side_controls_field_objective_type(battle, "enemy", "cover_line"):
				score += 2
		else:
			score += 4 if _battle_has_any_tags(battle, ["fortress_lane", "wall_pressure", "chokepoint"]) else 2
			if _side_controls_field_objective_type(battle, "enemy", "obstruction_line") and (
				_has_ability(stack, "formation_guard")
				or _has_ability(stack, "brace")
				or _has_ability(stack, "reach")
				or bool(stack.get("defending", false))
			):
				score += 2
		if _has_ability(stack, "formation_guard") or _has_ability(stack, "brace") or _has_ability(stack, "reach"):
			score += 2
		if _has_ability(stack, "bloodrush") or _has_ability(stack, "backstab") or _has_ability(stack, "harry"):
			score += 2
		score += int(round(float(int(stack.get("total_health", 0))) / 18.0))
		score += int(round(float(_stack_initiative_total(stack, battle)) / 3.0))
		if best.is_empty() or score > best_score:
			best = stack
			best_score = score
	return best

static func _priority_target_reason(stack: Dictionary, battle: Dictionary) -> String:
	if bool(stack.get("ranged", false)) and _battle_has_any_tags(battle, ["battery_nest", "elevated_fire", "open_lane"]):
		return "its ranged line controls the opening approach"
	if bool(stack.get("ranged", false)) and _side_controls_field_objective_type(battle, String(stack.get("side", "")), "cover_line"):
		return "it is firing from a screened cover line"
	if bool(stack.get("ranged", false)):
		return "it is the sharpest ranged threat on the field"
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "obstruction_line") and (_has_ability(stack, "formation_guard") or _has_ability(stack, "brace") or _has_ability(stack, "reach")):
		return "it is locking the obstruction line and taxing the approach"
	if _battle_has_any_tags(battle, ["fortress_lane", "wall_pressure", "chokepoint"]) and (_has_ability(stack, "formation_guard") or _has_ability(stack, "brace") or _has_ability(stack, "reach")):
		return "it anchors the tightest lane in the melee"
	if _has_ability(stack, "bloodrush") or _has_ability(stack, "backstab") or _has_ability(stack, "harry"):
		return "it can snowball fast once the line starts cracking"
	if _stack_initiative_total(stack, battle) >= 10:
		return "it will act early and pressure the first exchange"
	return "breaking it will soften the enemy line before reserves matter"

static func get_action_surface(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var surface = {}
	if session == null or session.battle.is_empty():
		return surface
	var battle = session.battle
	var active_stack = get_active_stack(battle)
	var target = get_selected_target(battle)
	var availability = action_availability(battle)
	var player_turn = not active_stack.is_empty() and String(active_stack.get("side", "")) == "player"
	var advance_summary = "Await the enemy move."
	if player_turn:
		advance_summary = _advance_action_summary(battle, active_stack) if bool(availability.get("advance", false)) else "The lines are already engaged."
	surface["advance"] = {
		"label": "Advance",
		"disabled": not player_turn or not bool(availability.get("advance", false)),
		"summary": advance_summary,
	}
	var strike_summary = "Await the enemy move."
	if player_turn:
		strike_summary = _attack_action_summary(active_stack, target, battle, false) if bool(availability.get("strike", false)) else "Close the distance or secure a target before striking."
	surface["strike"] = {
		"label": "Strike",
		"disabled": not player_turn or not bool(availability.get("strike", false)),
		"summary": strike_summary,
	}
	var shoot_summary = "Await the enemy move."
	if player_turn:
		shoot_summary = _attack_action_summary(active_stack, target, battle, true) if bool(availability.get("shoot", false)) else "Only ranged stacks with shots remaining can fire."
	surface["shoot"] = {
		"label": "Shoot",
		"disabled": not player_turn or not bool(availability.get("shoot", false)),
		"summary": shoot_summary,
	}
	surface["defend"] = {
		"label": "Defend",
		"disabled": not player_turn or not bool(availability.get("defend", false)),
		"summary": "Await the enemy move." if not player_turn else _defend_action_summary(battle, active_stack),
	}
	var retreat_summary = "Await the enemy move."
	if player_turn:
		retreat_summary = _retreat_action_summary(session)
	surface["retreat"] = {
		"label": "Retreat",
		"disabled": not player_turn or not bool(availability.get("retreat", false)),
		"summary": retreat_summary,
	}
	var surrender_summary = "Await the enemy move."
	if player_turn:
		surrender_summary = _surrender_action_summary(session)
	surface["surrender"] = {
		"label": "Surrender",
		"disabled": not player_turn or not bool(availability.get("surrender", false)),
		"summary": surrender_summary,
	}
	return surface

static func cast_player_spell(session: SessionStateStoreScript.SessionData, spell_id: String) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {"ok": false, "message": "No battle is active.", "state": "invalid"}

	var active_stack = get_active_stack(session.battle)
	var target_stack = get_selected_target(session.battle)
	var resolution = SpellRulesScript.resolve_battle_spell(
		_player_commander_state(session),
		session.battle,
		active_stack,
		target_stack,
		spell_id
	)
	if not bool(resolution.get("ok", false)):
		return {"ok": false, "message": String(resolution.get("message", "Spell casting failed.")), "state": "invalid"}

	session.battle["player_commander_state"] = resolution.get("hero", _player_commander_state(session))
	session.battle["player_hero"] = _hero_payload_from_state(
		_player_commander_state(session),
		ArtifactRulesScript.aggregate_bonuses(_player_commander_state(session)),
		session,
		"player"
	)
	var message = String(resolution.get("message", ""))
	var target_before = {}
	match String(resolution.get("resolution_type", "")):
		"damage":
			var target_battle_id = String(resolution.get("target_battle_id", ""))
			target_before = _get_stack_by_id(session.battle, target_battle_id)
			_apply_damage_to_stack(session.battle, target_battle_id, int(resolution.get("damage", 0)))
			var target_after = _get_stack_by_id(session.battle, target_battle_id)
			if not target_after.is_empty() and _alive_count(target_after) <= 0:
				message += " %s is destroyed." % _stack_label(target_after)
		"effect":
			_apply_stack_effect(
				session.battle,
				String(resolution.get("target_battle_id", "")),
				resolution.get("effect", {})
			)
		_:
			return {"ok": false, "message": "Unsupported spell resolution.", "state": "invalid"}
	var post_damage_effect = resolution.get("post_damage_effect", {})
	if post_damage_effect is Dictionary and not post_damage_effect.is_empty():
		var effect_target = _get_stack_by_id(session.battle, String(resolution.get("target_battle_id", "")))
		if not effect_target.is_empty() and _alive_count(effect_target) > 0:
			_apply_stack_effect(session.battle, String(resolution.get("target_battle_id", "")), post_damage_effect)
			message += " %s is %s." % [
				_stack_label(effect_target),
				String(post_damage_effect.get("label", "affected")).to_lower(),
			]
	if String(resolution.get("resolution_type", "")) == "damage":
		var spell_target_after = _get_stack_by_id(session.battle, String(resolution.get("target_battle_id", "")))
		var pressure_messages = _apply_damage_pressure(
			session.battle,
			active_stack,
			target_before,
			spell_target_after,
			true,
			"spell"
		)
		if not pressure_messages.is_empty():
			message = _join_messages([message, " ".join(pressure_messages)])
	var objective_messages = _apply_field_objective_action_pressure(
		session.battle,
		{
			"action": "cast_spell",
			"side": String(active_stack.get("side", "")),
			"battle_id": String(active_stack.get("battle_id", "")),
			"target_battle_id": String(resolution.get("target_battle_id", target_stack.get("battle_id", ""))),
		}
	)
	if not objective_messages.is_empty():
		message = _join_messages([message, " ".join(objective_messages)])

	return _complete_action(session, message)

static func perform_player_action(session: SessionStateStoreScript.SessionData, action: String) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {"ok": false, "message": "No battle is active.", "state": "invalid"}

	var active_stack = get_active_stack(session.battle)
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return {"ok": false, "message": "It is not the player's turn.", "state": "invalid"}

	match action:
		"advance":
			if int(session.battle.get("distance", 1)) <= 0:
				return {"ok": false, "message": "The lines are already engaged.", "state": "invalid"}
			session.battle["distance"] = int(session.battle.get("distance", 1)) - 1
			var advance_message = "%s advances." % _stack_label(active_stack)
			var advance_pressure = _apply_advance_pressure(session.battle, String(active_stack.get("battle_id", "")))
			if advance_pressure != "":
				advance_message += " %s" % advance_pressure
			var advance_objective_messages = _apply_field_objective_action_pressure(
				session.battle,
				{
					"action": "advance",
					"side": "player",
					"battle_id": String(active_stack.get("battle_id", "")),
				}
			)
			if not advance_objective_messages.is_empty():
				advance_message = _join_messages([advance_message, " ".join(advance_objective_messages)])
			return _complete_action(session, advance_message)
		"strike":
			if not _can_make_melee_attack(active_stack, session.battle):
				return {"ok": false, "message": "This stack cannot reach the enemy line yet.", "state": "invalid"}
			return _resolve_attack_action(session, active_stack, get_selected_target(session.battle), false)
		"shoot":
			if not bool(active_stack.get("ranged", false)):
				return {"ok": false, "message": "This stack cannot make a ranged attack.", "state": "invalid"}
			if int(active_stack.get("shots_remaining", 0)) <= 0:
				return {"ok": false, "message": "No shots remain for this stack.", "state": "invalid"}
			return _resolve_attack_action(session, active_stack, get_selected_target(session.battle), true)
		"defend":
			_set_stack_defending(session.battle, String(active_stack.get("battle_id", "")))
			var defend_message = "%s braces for impact." % _stack_label(active_stack)
			var defend_pressure = _apply_defend_pressure(session.battle, String(active_stack.get("battle_id", "")))
			if defend_pressure != "":
				defend_message += " %s" % defend_pressure
			var defend_objective_messages = _apply_field_objective_action_pressure(
				session.battle,
				{
					"action": "defend",
					"side": "player",
					"battle_id": String(active_stack.get("battle_id", "")),
				}
			)
			if not defend_objective_messages.is_empty():
				defend_message = _join_messages([defend_message, " ".join(defend_objective_messages)])
			return _complete_action(session, defend_message)
		"retreat":
			return _finalize_retreat(session)
		"surrender":
			return _finalize_surrender(session)
		_:
			return {"ok": false, "message": "Unknown action.", "state": "invalid"}

static func roster_lines(battle: Dictionary, side: String) -> Array:
	var lines = []
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary) or String(stack.get("side", "")) != side:
			continue
		lines.append(_stack_summary_line(stack, battle, String(battle.get("active_stack_id", "")), String(battle.get("selected_target_id", ""))))
	return lines

static func action_availability(battle: Dictionary) -> Dictionary:
	var active_stack = get_active_stack(battle)
	var selected_target = get_selected_target(battle)
	if active_stack.is_empty():
		return {
			"advance": false,
			"strike": false,
			"shoot": false,
			"defend": false,
			"retreat": false,
			"surrender": false,
		}

	return {
		"advance": int(battle.get("distance", 1)) > 0,
		"strike": not selected_target.is_empty() and _can_make_melee_attack(active_stack, battle),
		"shoot": (
			not selected_target.is_empty()
			and bool(active_stack.get("ranged", false))
			and int(active_stack.get("shots_remaining", 0)) > 0
		),
		"defend": true,
		"retreat": bool(battle.get("retreat_allowed", true)),
		"surrender": bool(battle.get("surrender_allowed", true)),
	}

static func _resolve_attack_action(
	session: SessionStateStoreScript.SessionData,
	attacker: Dictionary,
	target: Dictionary,
	is_ranged: bool
) -> Dictionary:
	if target.is_empty():
		return {"ok": false, "message": "No target is selected.", "state": "invalid"}

	var rng = RandomNumberGenerator.new()
	rng.seed = _battle_seed(session)
	rng.state = _battle_state_counter(session)

	var messages = []
	var attack_distance = int(session.battle.get("distance", 1))
	var target_before = target.duplicate(true)
	var damage = _calculate_damage(attacker, target, session.battle, rng, is_ranged, false, attack_distance)
	_apply_damage_to_stack(session.battle, String(target.get("battle_id", "")), damage)
	if is_ranged:
		_consume_shot(session.battle, String(attacker.get("battle_id", "")))
		messages.append("%s shoots %s for %d damage." % [_stack_label(attacker), _stack_label(target), damage])
	else:
		messages.append("%s strikes %s for %d damage." % [_stack_label(attacker), _stack_label(target), damage])

	var retaliated = false
	var defender_after = _get_stack_by_id(session.battle, String(target.get("battle_id", "")))
	messages.append_array(_apply_attack_ability_effects(session.battle, attacker, defender_after, is_ranged, attack_distance))
	defender_after = _get_stack_by_id(session.battle, String(target.get("battle_id", "")))
	messages.append_array(_apply_damage_pressure(session.battle, attacker, target_before, defender_after, is_ranged, "attack"))
	if (
		not is_ranged
		and not defender_after.is_empty()
		and _alive_count(defender_after) > 0
		and int(defender_after.get("retaliations_left", 0)) > 0
		and _can_make_retaliation(defender_after, attack_distance)
	):
		var attacker_after = _get_stack_by_id(session.battle, String(attacker.get("battle_id", "")))
		var attacker_before_retaliation = attacker_after.duplicate(true)
		var retaliation_damage = _calculate_damage(defender_after, attacker_after, session.battle, rng, false, true, attack_distance)
		_apply_damage_to_stack(session.battle, String(attacker.get("battle_id", "")), retaliation_damage)
		_consume_retaliation(session.battle, String(defender_after.get("battle_id", "")))
		messages.append("%s retaliates for %d damage." % [_stack_label(defender_after), retaliation_damage])
		var attacker_after_retaliation = _get_stack_by_id(session.battle, String(attacker.get("battle_id", "")))
		messages.append_array(_apply_retaliation_ability_effects(session.battle, defender_after, attacker_after_retaliation))
		attacker_after_retaliation = _get_stack_by_id(session.battle, String(attacker.get("battle_id", "")))
		messages.append_array(
			_apply_damage_pressure(
				session.battle,
				defender_after,
				attacker_before_retaliation,
				attacker_after_retaliation,
				false,
				"retaliation"
			)
		)
		retaliated = true

	var outcome = _evaluate_outcome(session)
	if String(outcome.get("state", "")) != "":
		_append_nonempty_message(messages, String(outcome.get("message", "")))
		return {"ok": true, "message": " ".join(messages), "state": String(outcome.get("state", ""))}

	if not retaliated and _alive_count(_get_stack_by_id(session.battle, String(target.get("battle_id", "")))) <= 0:
		messages.append("%s is destroyed." % _stack_label(target))
	var objective_messages = _apply_field_objective_action_pressure(
		session.battle,
		{
			"action": "shoot" if is_ranged else "strike",
			"side": String(attacker.get("side", "")),
			"battle_id": String(attacker.get("battle_id", "")),
			"target_battle_id": String(target.get("battle_id", "")),
		}
	)
	if not objective_messages.is_empty():
		messages.append(" ".join(objective_messages))

	return _complete_action(session, " ".join(messages))

static func _complete_action(session: SessionStateStoreScript.SessionData, initial_message: String) -> Dictionary:
	var messages = [initial_message]
	_record_event(session.battle, initial_message)
	var outcome = _evaluate_outcome(session)
	if String(outcome.get("state", "")) != "":
		_append_nonempty_message(messages, String(outcome.get("message", "")))
		return {"ok": true, "message": " ".join(messages), "state": String(outcome.get("state", ""))}

	advance_turn(session.battle)
	outcome = _evaluate_outcome(session)
	if String(outcome.get("state", "")) != "":
		_append_nonempty_message(messages, String(outcome.get("message", "")))
		return {"ok": true, "message": " ".join(messages), "state": String(outcome.get("state", ""))}

	var enemy_result := _drain_enemy_turns(session)
	_append_nonempty_message(messages, String(enemy_result.get("message", "")))
	var enemy_state := String(enemy_result.get("state", "continue"))
	if enemy_state != "" and enemy_state != "continue":
		return {"ok": true, "message": " ".join(messages), "state": enemy_state}
	return {"ok": true, "message": " ".join(messages), "state": "continue"}

static func advance_turn(battle: Dictionary) -> void:
	var turn_order = battle.get("turn_order", [])
	if not (turn_order is Array) or turn_order.is_empty():
		_prepare_round(battle, max(1, int(battle.get("round", 1))))
		return

	var next_index = int(battle.get("turn_index", 0)) + 1
	var next_id = _advance_to_next_alive(battle, next_index)
	if next_id == "":
		_prepare_round(battle, int(battle.get("round", 1)) + 1)
	else:
		battle["turn_index"] = next_index
		battle["active_stack_id"] = next_id
	_assign_default_target(battle)

static func _run_enemy_turn(session: SessionStateStoreScript.SessionData, active_stack: Dictionary) -> Dictionary:
	if active_stack.is_empty():
		return {"ok": false, "message": "", "state": "invalid"}

	var targets = _alive_stacks_for_side(session.battle, "player")
	if targets.is_empty():
		var defeat_result = _finalize_player_battle_loss(session)
		return {
			"ok": true,
			"message": _join_messages(["The army is broken.", String(defeat_result.get("message", ""))]),
			"state": String(defeat_result.get("state", "defeat")),
		}

	var action = BattleAiRulesScript.choose_enemy_action(
		session.battle,
		active_stack,
		session.battle.get("enemy_hero", {})
	)
	match String(action.get("action", "")):
		"cast_spell":
			return _cast_enemy_spell(session, active_stack, action)
		"shoot":
			return _resolve_ai_attack(
				session,
				active_stack,
				_get_stack_by_id(session.battle, String(action.get("target_battle_id", ""))),
				true
			)
		"strike":
			return _resolve_ai_attack(
				session,
				active_stack,
				_get_stack_by_id(session.battle, String(action.get("target_battle_id", ""))),
				false
			)
		"advance":
			session.battle["distance"] = max(0, int(session.battle.get("distance", 1)) - 1)
			var advance_message = "%s advances." % _stack_label(active_stack)
			var advance_pressure = _apply_advance_pressure(session.battle, String(active_stack.get("battle_id", "")))
			if advance_pressure != "":
				advance_message += " %s" % advance_pressure
			var advance_objective_messages = _apply_field_objective_action_pressure(
				session.battle,
				{
					"action": "advance",
					"side": "enemy",
					"battle_id": String(active_stack.get("battle_id", "")),
				}
			)
			if not advance_objective_messages.is_empty():
				advance_message = _join_messages([advance_message, " ".join(advance_objective_messages)])
			return _complete_enemy_action(session, advance_message)
		"defend":
			_set_stack_defending(session.battle, String(active_stack.get("battle_id", "")))
			var defend_message = "%s braces for impact." % _stack_label(active_stack)
			var defend_pressure = _apply_defend_pressure(session.battle, String(active_stack.get("battle_id", "")))
			if defend_pressure != "":
				defend_message += " %s" % defend_pressure
			var defend_objective_messages = _apply_field_objective_action_pressure(
				session.battle,
				{
					"action": "defend",
					"side": "enemy",
					"battle_id": String(active_stack.get("battle_id", "")),
				}
			)
			if not defend_objective_messages.is_empty():
				defend_message = _join_messages([defend_message, " ".join(defend_objective_messages)])
			return _complete_enemy_action(session, defend_message)
		_:
			var fallback = _lowest_health_stack(targets)
			if bool(active_stack.get("ranged", false)) and int(active_stack.get("shots_remaining", 0)) > 0:
				return _resolve_ai_attack(session, active_stack, fallback, true)
			if int(session.battle.get("distance", 1)) > 0:
				session.battle["distance"] = max(0, int(session.battle.get("distance", 1)) - 1)
				var fallback_advance_message = "%s advances." % _stack_label(active_stack)
				var fallback_advance_pressure = _apply_advance_pressure(session.battle, String(active_stack.get("battle_id", "")))
				if fallback_advance_pressure != "":
					fallback_advance_message += " %s" % fallback_advance_pressure
				var fallback_objective_messages = _apply_field_objective_action_pressure(
					session.battle,
					{
						"action": "advance",
						"side": "enemy",
						"battle_id": String(active_stack.get("battle_id", "")),
					}
				)
				if not fallback_objective_messages.is_empty():
					fallback_advance_message = _join_messages([fallback_advance_message, " ".join(fallback_objective_messages)])
				return _complete_enemy_action(session, fallback_advance_message)
			return _resolve_ai_attack(session, active_stack, fallback, false)

static func _cast_enemy_spell(session: SessionStateStoreScript.SessionData, active_stack: Dictionary, action: Dictionary) -> Dictionary:
	var target = _get_stack_by_id(session.battle, String(action.get("target_battle_id", "")))
	var resolution = SpellRulesScript.resolve_battle_spell(
		session.battle.get("enemy_hero", {}),
		session.battle,
		active_stack,
		target,
		String(action.get("spell_id", "")),
		"enemy"
	)
	if not bool(resolution.get("ok", false)):
		return {"ok": false, "message": String(resolution.get("message", "")), "state": "invalid"}

	session.battle["enemy_hero"] = resolution.get("hero", session.battle.get("enemy_hero", {}))
	session.battle["enemy_hero_payload"] = _hero_payload_from_state(session.battle.get("enemy_hero", {}), {}, session, "enemy")
	var message = String(resolution.get("message", ""))
	var target_before = {}
	match String(resolution.get("resolution_type", "")):
		"damage":
			var target_battle_id = String(resolution.get("target_battle_id", ""))
			target_before = _get_stack_by_id(session.battle, target_battle_id)
			_apply_damage_to_stack(session.battle, target_battle_id, int(resolution.get("damage", 0)))
			var target_after = _get_stack_by_id(session.battle, target_battle_id)
			if not target_after.is_empty() and _alive_count(target_after) <= 0:
				message += " %s is destroyed." % _stack_label(target_after)
		"effect":
			_apply_stack_effect(
				session.battle,
				String(resolution.get("target_battle_id", "")),
				resolution.get("effect", {})
			)
		_:
			return {"ok": false, "message": "Unsupported spell resolution.", "state": "invalid"}
	var post_damage_effect = resolution.get("post_damage_effect", {})
	if post_damage_effect is Dictionary and not post_damage_effect.is_empty():
		var effect_target = _get_stack_by_id(session.battle, String(resolution.get("target_battle_id", "")))
		if not effect_target.is_empty() and _alive_count(effect_target) > 0:
			_apply_stack_effect(session.battle, String(resolution.get("target_battle_id", "")), post_damage_effect)
			message += " %s is %s." % [
				_stack_label(effect_target),
				String(post_damage_effect.get("label", "affected")).to_lower(),
			]
	if String(resolution.get("resolution_type", "")) == "damage":
		var spell_target_after = _get_stack_by_id(session.battle, String(resolution.get("target_battle_id", "")))
		var pressure_messages = _apply_damage_pressure(
			session.battle,
			active_stack,
			target_before,
			spell_target_after,
			true,
			"spell"
		)
		if not pressure_messages.is_empty():
			message = _join_messages([message, " ".join(pressure_messages)])
	var objective_messages = _apply_field_objective_action_pressure(
		session.battle,
		{
			"action": "cast_spell",
			"side": String(active_stack.get("side", "")),
			"battle_id": String(active_stack.get("battle_id", "")),
			"target_battle_id": String(action.get("target_battle_id", "")),
		}
	)
	if not objective_messages.is_empty():
		message = _join_messages([message, " ".join(objective_messages)])

	return _complete_enemy_action(session, message)

static func _resolve_ai_attack(session: SessionStateStoreScript.SessionData, attacker: Dictionary, target: Dictionary, is_ranged: bool) -> Dictionary:
	if target.is_empty():
		return {"ok": false, "message": "", "state": "invalid"}
	var rng = RandomNumberGenerator.new()
	rng.seed = _battle_seed(session)
	rng.state = _battle_state_counter(session)
	var messages = []
	var attack_distance = int(session.battle.get("distance", 1))
	var target_before = target.duplicate(true)
	var damage = _calculate_damage(attacker, target, session.battle, rng, is_ranged, false, attack_distance)
	_apply_damage_to_stack(session.battle, String(target.get("battle_id", "")), damage)
	if is_ranged:
		_consume_shot(session.battle, String(attacker.get("battle_id", "")))
		messages.append("%s fires on %s for %d damage." % [_stack_label(attacker), _stack_label(target), damage])
	else:
		messages.append("%s batters %s for %d damage." % [_stack_label(attacker), _stack_label(target), damage])

	var defender_after = _get_stack_by_id(session.battle, String(target.get("battle_id", "")))
	messages.append_array(_apply_attack_ability_effects(session.battle, attacker, defender_after, is_ranged, attack_distance))
	defender_after = _get_stack_by_id(session.battle, String(target.get("battle_id", "")))
	messages.append_array(_apply_damage_pressure(session.battle, attacker, target_before, defender_after, is_ranged, "attack"))
	if (
		not is_ranged
		and not defender_after.is_empty()
		and _alive_count(defender_after) > 0
		and int(defender_after.get("retaliations_left", 0)) > 0
		and _can_make_retaliation(defender_after, attack_distance)
	):
		var attacker_after = _get_stack_by_id(session.battle, String(attacker.get("battle_id", "")))
		var attacker_before_retaliation = attacker_after.duplicate(true)
		var retaliation_damage = _calculate_damage(defender_after, attacker_after, session.battle, rng, false, true, attack_distance)
		_apply_damage_to_stack(session.battle, String(attacker.get("battle_id", "")), retaliation_damage)
		_consume_retaliation(session.battle, String(defender_after.get("battle_id", "")))
		messages.append("%s retaliates for %d damage." % [_stack_label(defender_after), retaliation_damage])
		var attacker_after_retaliation = _get_stack_by_id(session.battle, String(attacker.get("battle_id", "")))
		messages.append_array(_apply_retaliation_ability_effects(session.battle, defender_after, attacker_after_retaliation))
		attacker_after_retaliation = _get_stack_by_id(session.battle, String(attacker.get("battle_id", "")))
		messages.append_array(
			_apply_damage_pressure(
				session.battle,
				defender_after,
				attacker_before_retaliation,
				attacker_after_retaliation,
				false,
				"retaliation"
			)
		)
	var objective_messages = _apply_field_objective_action_pressure(
		session.battle,
		{
			"action": "shoot" if is_ranged else "strike",
			"side": String(attacker.get("side", "")),
			"battle_id": String(attacker.get("battle_id", "")),
			"target_battle_id": String(target.get("battle_id", "")),
		}
	)
	if not objective_messages.is_empty():
		messages.append(" ".join(objective_messages))

	return _complete_enemy_action(session, " ".join(messages))

static func _drain_enemy_turns(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {"state": "invalid", "message": ""}

	var messages := []
	while true:
		var active_stack = get_active_stack(session.battle)
		if active_stack.is_empty():
			var outcome = _evaluate_outcome(session)
			if String(outcome.get("state", "")) != "":
				return outcome
			break
		if String(active_stack.get("side", "")) != "enemy":
			break
		var enemy_result = _run_enemy_turn(session, active_stack)
		var enemy_message := String(enemy_result.get("message", ""))
		if enemy_message != "":
			_record_event(session.battle, enemy_message)
			messages.append(enemy_message)
		var enemy_state := String(enemy_result.get("state", "continue"))
		if enemy_state != "" and enemy_state not in ["continue", "invalid"]:
			return {"state": enemy_state, "message": " ".join(messages)}
		if enemy_state == "invalid":
			break

	return {"state": "continue", "message": " ".join(messages)}

static func _complete_enemy_action(session: SessionStateStoreScript.SessionData, message: String) -> Dictionary:
	var outcome = _evaluate_outcome(session)
	if String(outcome.get("state", "")) != "":
		return {
			"ok": true,
			"message": _join_messages([message, String(outcome.get("message", ""))]),
			"state": String(outcome.get("state", "")),
		}
	advance_turn(session.battle)
	outcome = _evaluate_outcome(session)
	if String(outcome.get("state", "")) != "":
		return {
			"ok": true,
			"message": _join_messages([message, String(outcome.get("message", ""))]),
			"state": String(outcome.get("state", "")),
		}
	return {"ok": true, "message": message, "state": "continue"}

static func _evaluate_outcome(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var player_alive = not _alive_stacks_for_side(session.battle, "player").is_empty()
	var enemy_alive = not _alive_stacks_for_side(session.battle, "enemy").is_empty()
	if not enemy_alive and player_alive:
		return _finalize_victory(session)
	if not player_alive:
		return _finalize_player_battle_loss(session)
	if int(session.battle.get("round", 1)) > int(session.battle.get("max_rounds", 12)):
		return _finalize_stalemate(session)
	return {"state": "", "message": ""}

static func _finalize_victory(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var messages = []
	var base_summary := _apply_battle_context_victory(session)
	if base_summary == "":
		base_summary = "The enemy host breaks and the battlefield is secured."
	messages.append(base_summary)
	if not _is_town_assault_context(session.battle.get("context", {})):
		_mark_resolved_encounter(session, String(session.battle.get("resolved_key", "")))

	var encounter = ContentService.get_encounter(String(session.battle.get("encounter_id", "")))
	var rewards = DifficultyRulesScript.scale_reward_resources(session, encounter.get("rewards", {}))
	OverworldRulesScript._add_resources(session, rewards)
	var reward_summary = OverworldRulesScript._describe_resource_delta(rewards)
	if reward_summary != "":
		messages.append("Battle rewards %s." % reward_summary)
	var experience_amount = max(0, int(rewards.get("experience", 0)))
	if experience_amount > 0:
		var hero_name = String(_player_commander_state(session).get("name", "The commander"))
		messages.append("%s gains %d experience." % [hero_name, experience_amount])
	messages.append_array(_award_commander_experience(session, experience_amount))
	_sync_player_force_from_battle(session)
	var front_result := _apply_victory_front_aftermath(session)
	_append_nonempty_message(messages, String(front_result.get("summary", "")))
	_append_nonempty_message(messages, _apply_delivery_route_aftermath(session, "victory"))
	_sync_enemy_force_from_battle(session, true)
	HeroCommandRulesScript.commit_active_hero(session)
	OverworldRulesScript.refresh_fog_of_war(session)

	var victory_flags = encounter.get("victory_flags", [])
	if victory_flags is Array:
		for flag_value in victory_flags:
			session.flags[String(flag_value)] = true

	session.flags["last_battle_outcome"] = "victory"
	_record_battle_aftermath(
		session,
		"victory",
		base_summary,
		{
			"resource_summary": "Battle rewards %s." % reward_summary if reward_summary != "" else "",
			"pressure_summary": String(front_result.get("summary", "")),
			"recovery_summary": "",
		}
	)
	session.battle = {}
	var scenario_result = ScenarioRulesScript.evaluate_session(session)
	_append_nonempty_message(messages, String(scenario_result.get("message", "")))
	var final_message = " ".join(messages)
	if session.scenario_status == "in_progress" and final_message != "":
		session.flags["return_notice"] = final_message
	return {"state": "victory", "message": final_message}

static func _finalize_player_battle_loss(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if _is_town_defense_context(session.battle.get("context", {})):
		return _finalize_town_defense_loss(session)
	if HeroCommandRulesScript.active_hero_is_primary(session):
		if _is_town_assault_context(session.battle.get("context", {})):
			return _finalize_primary_defeat(session, "The assault collapses beneath the walls and the primary commander is defeated.")
		return _finalize_primary_defeat(session)
	return _finalize_secondary_hero_defeat(session)

static func _finalize_primary_defeat(
	session: SessionStateStoreScript.SessionData,
	base_summary: String = "The field army collapses and the primary commander is defeated.",
	outcome_id: String = "defeat"
) -> Dictionary:
	_sync_player_force_from_battle(session)
	_sync_enemy_force_from_battle(session, false)
	var delivery_summary: String = _apply_delivery_route_aftermath(session, outcome_id)
	OverworldRulesScript.refresh_fog_of_war(session)
	session.flags["last_battle_outcome"] = outcome_id
	session.flags["campaign"] = "defeat"
	if session.scenario_status == "in_progress":
		session.scenario_status = "defeat"
		if session.scenario_summary == "":
			session.scenario_summary = "The primary commander is defeated."
	_record_battle_aftermath(session, outcome_id, base_summary)
	session.battle = {}
	var scenario_result = ScenarioRulesScript.evaluate_session(session)
	var final_message = _join_messages([base_summary, delivery_summary, String(scenario_result.get("message", ""))])
	return {"state": "defeat", "message": final_message}

static func _finalize_secondary_hero_defeat(session: SessionStateStoreScript.SessionData) -> Dictionary:
	_sync_enemy_force_from_battle(session, false)
	var delivery_summary: String = _apply_delivery_route_aftermath(session, "hero_defeat")
	var removal = HeroCommandRulesScript.remove_active_hero_after_defeat(session)
	session.flags["last_battle_outcome"] = "hero_defeat"
	var messages = [String(removal.get("message", "A commander falls in battle."))]
	_append_nonempty_message(messages, delivery_summary)
	var next_active_name = String(removal.get("next_active_name", ""))
	if next_active_name != "":
		messages.append("%s takes command." % next_active_name)
	_record_battle_aftermath(session, "hero_defeat", String(messages[0]))
	session.battle = {}
	OverworldRulesScript.refresh_fog_of_war(session)
	var scenario_result = ScenarioRulesScript.evaluate_session(session)
	_append_nonempty_message(messages, String(scenario_result.get("message", "")))
	var final_message = " ".join(messages)
	if session.scenario_status == "in_progress" and final_message != "":
		session.flags["return_notice"] = final_message
	return {"state": "hero_defeat", "message": final_message}

static func _finalize_retreat(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if _is_town_defense_context(session.battle.get("context", {})):
		return {"ok": false, "message": "Town defenders cannot abandon the walls mid-assault.", "state": "invalid"}
	var base_summary := "The army withdraws from battle."
	if _is_town_assault_context(session.battle.get("context", {})):
		base_summary = "The assault breaks off from the walls."
	var messages = [base_summary]
	_sync_player_force_from_battle(session)
	_sync_enemy_force_from_battle(session, false)
	var aftermath := _apply_withdrawal_aftermath(session, "retreat")
	_append_nonempty_message(messages, String(aftermath.get("summary", "")))
	_append_nonempty_message(messages, _apply_delivery_route_aftermath(session, "retreat"))
	HeroCommandRulesScript.commit_active_hero(session)
	OverworldRulesScript.refresh_fog_of_war(session)
	session.flags["last_battle_outcome"] = "retreat"
	_record_battle_aftermath(session, "retreat", base_summary, aftermath)
	session.battle = {}
	var scenario_result = ScenarioRulesScript.evaluate_session(session)
	_append_nonempty_message(messages, String(scenario_result.get("message", "")))
	var final_message = " ".join(messages)
	if session.scenario_status == "in_progress" and final_message != "":
		session.flags["return_notice"] = final_message
	return {"ok": true, "message": final_message, "state": "retreat"}

static func _finalize_surrender(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if _is_town_defense_context(session.battle.get("context", {})):
		return {"ok": false, "message": "Town defenders cannot surrender the walls mid-assault.", "state": "invalid"}
	var base_summary := "The commander lowers the banners and yields the field."
	if _is_town_assault_context(session.battle.get("context", {})):
		base_summary = "The commander yields the assault beneath the walls."
	var messages = [base_summary]
	_sync_player_force_from_battle(session)
	_sync_enemy_force_from_battle(session, false)
	var aftermath := _apply_withdrawal_aftermath(session, "surrender")
	_append_nonempty_message(messages, String(aftermath.get("summary", "")))
	_append_nonempty_message(messages, _apply_delivery_route_aftermath(session, "surrender"))
	HeroCommandRulesScript.commit_active_hero(session)
	OverworldRulesScript.refresh_fog_of_war(session)
	session.flags["last_battle_outcome"] = "surrender"
	_record_battle_aftermath(session, "surrender", base_summary, aftermath)
	session.battle = {}
	var scenario_result = ScenarioRulesScript.evaluate_session(session)
	_append_nonempty_message(messages, String(scenario_result.get("message", "")))
	var final_message = " ".join(messages)
	if session.scenario_status == "in_progress" and final_message != "":
		session.flags["return_notice"] = final_message
	return {"ok": true, "message": final_message, "state": "surrender"}

static func _finalize_stalemate(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var messages = []
	var base_summary := _apply_battle_context_stalemate(session)
	if base_summary == "":
		base_summary = "Both armies disengage before a decisive break."
	messages.append(base_summary)
	_sync_player_force_from_battle(session)
	_sync_enemy_force_from_battle(session, false)
	_append_nonempty_message(messages, _apply_delivery_route_aftermath(session, "stalemate"))
	HeroCommandRulesScript.commit_active_hero(session)
	OverworldRulesScript.refresh_fog_of_war(session)
	session.flags["last_battle_outcome"] = "stalemate"
	_record_battle_aftermath(session, "stalemate", base_summary)
	session.battle = {}
	var scenario_result = ScenarioRulesScript.evaluate_session(session)
	_append_nonempty_message(messages, String(scenario_result.get("message", "")))
	var final_message = " ".join(messages)
	if session.scenario_status == "in_progress" and final_message != "":
		session.flags["return_notice"] = final_message
	return {"state": "stalemate", "message": final_message}

static func _apply_victory_front_aftermath(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {"summary": ""}
	var faction_id := _battle_enemy_faction_id(session)
	if faction_id == "":
		return {"summary": ""}
	var encounter = _current_battle_encounter_placement(session)
	var pressure_delta := -1
	if (
		_is_town_defense_context(session.battle.get("context", {}))
		or _is_town_assault_context(session.battle.get("context", {}))
		or String(encounter.get("spawned_by_faction_id", "")) != ""
	):
		pressure_delta = -2
	var pressure_summary := _apply_front_pressure_shift(session, faction_id, pressure_delta, "victory")
	return {"summary": pressure_summary}

static func _apply_withdrawal_aftermath(session: SessionStateStoreScript.SessionData, outcome: String) -> Dictionary:
	var preview := _build_withdrawal_aftermath_preview(session, outcome)
	var resource_summary := ""
	var army_summary := ""
	var pressure_summary := ""
	var recovery_summary := ""
	var resource_loss = preview.get("resource_loss", {})
	if resource_loss is Dictionary and not resource_loss.is_empty():
		OverworldRulesScript._spend_resources(session, resource_loss)
		_add_enemy_treasury_resources(session, String(preview.get("enemy_faction_id", "")), resource_loss)
		resource_summary = _withdrawal_resource_summary(outcome, resource_loss, String(preview.get("enemy_label", "The enemy")))
	army_summary = _apply_active_hero_aftermath_losses(session, int(preview.get("casualty_units", 0)), outcome)
	pressure_summary = _apply_front_pressure_shift(
		session,
		String(preview.get("enemy_faction_id", "")),
		int(preview.get("pressure_delta", 0)),
		outcome
	)
	recovery_summary = _apply_withdrawal_recovery_pressure(
		session,
		String(preview.get("nearest_town_placement_id", "")),
		int(preview.get("recovery_pressure", 0)),
		outcome
	)
	var summary := _join_messages([resource_summary, army_summary, pressure_summary, recovery_summary])
	if summary == "":
		summary = (
			"The surrender terms keep the survivors together."
			if outcome == "surrender"
			else "The rearguard keeps the withdrawal orderly."
		)
	return {
		"summary": summary,
		"resource_summary": resource_summary,
		"army_summary": army_summary,
		"pressure_summary": pressure_summary,
		"recovery_summary": recovery_summary,
	}

static func _withdrawal_resource_summary(outcome: String, resource_loss: Dictionary, enemy_label: String) -> String:
	var resource_summary = OverworldRulesScript._describe_resource_delta(resource_loss)
	if resource_summary == "":
		return ""
	if outcome == "surrender":
		return "%s confiscates %s as surrender terms." % [enemy_label, resource_summary]
	if enemy_label != "":
		return "%s seizes %s from the baggage train." % [enemy_label, resource_summary]
	return "The withdrawal abandons %s on the road." % resource_summary

static func _apply_active_hero_aftermath_losses(
	session: SessionStateStoreScript.SessionData,
	unit_losses: int,
	outcome: String
) -> String:
	var commander_source = session.battle.get("player_commander_source", {})
	var hero_id := String(commander_source.get("hero_id", session.overworld.get("active_hero_id", "")))
	if hero_id == "":
		return ""
	var hero = HeroCommandRulesScript.hero_by_id(session, hero_id)
	if hero.is_empty():
		return ""
	var army: Dictionary = hero.get("army", {}).duplicate(true) if hero.get("army", {}) is Dictionary else {}
	var stacks: Array = army.get("stacks", []).duplicate(true) if army.get("stacks", []) is Array else []
	var before_units: int = _stack_count_total(stacks)
	if before_units <= 0:
		return ""
	var before_companies: int = stacks.size()
	var applied_losses: int = _remove_units_from_stacks(stacks, unit_losses)
	army["stacks"] = stacks
	hero["army"] = army
	_set_player_hero_state(session, hero, hero_id)
	var after_companies: int = stacks.size()
	if applied_losses <= 0:
		return (
			"The surrender terms spare the surviving companies from further bloodshed."
			if outcome == "surrender"
			else "The surviving companies keep formation through the retreat."
		)
	var broken_companies: int = maxi(0, before_companies - after_companies)
	if outcome == "surrender":
		return "Disarmament and stragglers cost %d troop%s, but %d compan%s remain under command." % [
			applied_losses,
			"" if applied_losses == 1 else "s",
			after_companies,
			"y" if after_companies == 1 else "ies",
		]
	var company_clause := ""
	if broken_companies > 0:
		company_clause = " and breaks %d compan%s" % [
			broken_companies,
			"y" if broken_companies == 1 else "ies",
		]
	return "Pursuit scatters %d troop%s%s." % [
		applied_losses,
		"" if applied_losses == 1 else "s",
		company_clause,
	]

static func _remove_units_from_stacks(stacks: Array, unit_losses: int) -> int:
	var total_units: int = _stack_count_total(stacks)
	var remaining_losses: int = clampi(unit_losses, 0, maxi(0, total_units - 1))
	var applied: int = 0
	while remaining_losses > 0 and not stacks.is_empty():
		var largest_index := -1
		var largest_count := -1
		for index in range(stacks.size()):
			var stack = stacks[index]
			if not (stack is Dictionary):
				continue
			var count = max(0, int(stack.get("count", 0)))
			if count > largest_count:
				largest_count = count
				largest_index = index
		if largest_index < 0 or largest_count <= 0:
			break
		var target = stacks[largest_index]
		target["count"] = max(0, int(target.get("count", 0)) - 1)
		if int(target.get("count", 0)) <= 0:
			stacks.remove_at(largest_index)
		else:
			stacks[largest_index] = target
		remaining_losses -= 1
		applied += 1
	return applied

static func _apply_front_pressure_shift(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	delta: int,
	outcome: String
) -> String:
	var applied := _adjust_enemy_pressure(session, faction_id, delta)
	if applied == 0:
		return ""
	var faction_name := _battle_enemy_label(session, faction_id)
	if applied > 0:
		var reason := "the broken contact" if outcome == "retreat" else "the capitulation"
		return "%s front pressure rises by %d after %s." % [faction_name, applied, reason]
	return "%s front pressure drops by %d after the field is secured." % [faction_name, abs(applied)]

static func _adjust_enemy_pressure(session: SessionStateStoreScript.SessionData, faction_id: String, delta: int) -> int:
	if session == null or faction_id == "" or delta == 0:
		return 0
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return 0
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var current = max(0, int(state.get("pressure", 0)))
		var updated = max(0, current + delta)
		state["pressure"] = updated
		states[index] = state
		session.overworld["enemy_states"] = states
		return updated - current
	return 0

static func _add_enemy_treasury_resources(
	session: SessionStateStoreScript.SessionData,
	faction_id: String,
	delta: Dictionary
) -> void:
	if session == null or faction_id == "" or delta.is_empty():
		return
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var treasury = state.get("treasury", {}).duplicate(true) if state.get("treasury", {}) is Dictionary else {}
		for resource_key in ["gold", "wood", "ore"]:
			treasury[resource_key] = max(0, int(treasury.get(resource_key, 0)) + int(delta.get(resource_key, 0)))
		state["treasury"] = treasury
		states[index] = state
		session.overworld["enemy_states"] = states
		return

static func _apply_withdrawal_recovery_pressure(
	session: SessionStateStoreScript.SessionData,
	town_placement_id: String,
	pressure: int,
	outcome: String
) -> String:
	if town_placement_id == "" or pressure <= 0:
		return ""
	var source := "surrender column" if outcome == "surrender" else "scattered survivors"
	return OverworldRulesScript.apply_town_recovery_pressure(session, town_placement_id, pressure, source)

static func _record_battle_aftermath(
	session: SessionStateStoreScript.SessionData,
	outcome: String,
	summary: String,
	details: Dictionary = {}
) -> void:
	if session == null:
		return
	var headline := "Battle Aftermath | %s" % _titleize_token(outcome)
	if not session.battle.is_empty():
		headline = "%s | %s" % [headline, String(session.battle.get("encounter_name", session.battle.get("encounter_id", "Battle")))]
	session.flags["last_battle_aftermath"] = {
		"outcome": outcome,
		"headline": headline,
		"summary": summary,
		"resource_summary": String(details.get("resource_summary", "")),
		"army_summary": String(details.get("army_summary", "")),
		"pressure_summary": String(details.get("pressure_summary", "")),
		"recovery_summary": String(details.get("recovery_summary", "")),
		"day": session.day,
	}

static func _append_nonempty_message(messages: Array, message: String) -> void:
	if message != "":
		messages.append(message)

static func _join_messages(parts: Array) -> String:
	var messages = []
	for value in parts:
		var message = String(value)
		if message != "":
			messages.append(message)
	return " ".join(messages)

static func _build_battle_stack(
	unit_id: String,
	count: int,
	side: String,
	index: int,
	source: Dictionary = {}
) -> Dictionary:
	var unit = ContentService.get_unit(unit_id)
	if unit.is_empty():
		return {}
	var unit_hp = max(1, int(unit.get("hp", 1)))
	var cohesion_base = _cohesion_base_for_unit(unit)
	return {
		"battle_id": "%s_%d_%s" % [side, index, unit_id],
		"side": side,
		"faction_id": String(unit.get("faction_id", "")),
		"unit_id": unit_id,
		"name": String(unit.get("name", unit_id)),
		"unit_hp": unit_hp,
		"total_health": max(0, count) * unit_hp,
		"base_count": max(0, count),
		"attack": int(unit.get("attack", 0)),
		"defense": int(unit.get("defense", 0)),
		"min_damage": int(unit.get("min_damage", 1)),
		"max_damage": int(unit.get("max_damage", 1)),
		"initiative": int(unit.get("initiative", 1)),
		"speed": int(unit.get("speed", 1)),
		"ranged": bool(unit.get("ranged", false)),
		"retaliations": max(0, int(unit.get("retaliations", 1))),
		"retaliations_left": max(0, int(unit.get("retaliations", 1))),
		"shots_remaining": int(unit.get("shots", 0)),
		"defending": false,
		"cohesion_base": cohesion_base,
		"cohesion": cohesion_base,
		"momentum": 0,
		"abilities": _normalize_unit_abilities(unit.get("abilities", [])),
		"effects": [],
		"source_type": String(source.get("source_type", "")),
		"source_hero_id": String(source.get("hero_id", "")),
		"source_town_placement_id": String(source.get("town_placement_id", "")),
		"source_encounter_key": String(source.get("encounter_key", "")),
	}

static func _normalize_stack(stack: Variant) -> Dictionary:
	if not (stack is Dictionary):
		return {}
	var unit_id = String(stack.get("unit_id", ""))
	if unit_id == "":
		return {}
	var unit = ContentService.get_unit(unit_id)
	if unit.is_empty():
		return {}
	var unit_hp = max(1, int(unit.get("hp", 1)))
	var cohesion_base = _cohesion_base_for_unit(unit)
	return {
		"battle_id": String(stack.get("battle_id", "%s_%s" % [String(stack.get("side", "stack")), unit_id])),
		"side": String(stack.get("side", "player")),
		"faction_id": String(stack.get("faction_id", unit.get("faction_id", ""))),
		"unit_id": unit_id,
		"name": String(stack.get("name", unit.get("name", unit_id))),
		"unit_hp": unit_hp,
		"total_health": max(0, int(stack.get("total_health", int(stack.get("base_count", 0)) * unit_hp))),
		"base_count": max(0, int(stack.get("base_count", 0))),
		"attack": int(stack.get("attack", unit.get("attack", 0))),
		"defense": int(stack.get("defense", unit.get("defense", 0))),
		"min_damage": int(stack.get("min_damage", unit.get("min_damage", 1))),
		"max_damage": int(stack.get("max_damage", unit.get("max_damage", 1))),
		"initiative": int(stack.get("initiative", unit.get("initiative", 1))),
		"speed": int(stack.get("speed", unit.get("speed", 1))),
		"ranged": bool(stack.get("ranged", unit.get("ranged", false))),
		"retaliations": max(0, int(stack.get("retaliations", unit.get("retaliations", 1)))),
		"retaliations_left": max(0, int(stack.get("retaliations_left", unit.get("retaliations", 1)))),
		"shots_remaining": max(0, int(stack.get("shots_remaining", unit.get("shots", 0)))),
		"defending": bool(stack.get("defending", false)),
		"cohesion_base": clamp(int(stack.get("cohesion_base", cohesion_base)), COHESION_MIN, COHESION_MAX),
		"cohesion": clamp(int(stack.get("cohesion", stack.get("cohesion_base", cohesion_base))), COHESION_MIN, COHESION_MAX),
		"momentum": clamp(int(stack.get("momentum", 0)), 0, MOMENTUM_MAX),
		"abilities": _normalize_unit_abilities(unit.get("abilities", [])),
		"effects": stack.get("effects", []).duplicate(true) if stack.get("effects", []) is Array else [],
		"source_type": String(stack.get("source_type", "")),
		"source_hero_id": String(stack.get("source_hero_id", "")),
		"source_town_placement_id": String(stack.get("source_town_placement_id", "")),
		"source_encounter_key": String(stack.get("source_encounter_key", "")),
	}

static func _prepare_round(battle: Dictionary, round_number: int) -> void:
	battle["round"] = round_number
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary):
			continue
		stack = SpellRulesScript.purge_expired_stack_effects(stack, round_number)
		stack["defending"] = false
		stack["retaliations_left"] = int(stack.get("retaliations", 1))
		stack["momentum"] = max(0, int(stack.get("momentum", 0)) - 1)
		stacks[index] = stack
	battle["stacks"] = stacks
	_apply_round_pressure_shifts(battle)
	battle["turn_order"] = _sorted_turn_order(battle)
	battle["turn_index"] = 0
	battle["active_stack_id"] = _advance_to_next_alive(battle, 0)
	_assign_default_target(battle)
	var active_stack = get_active_stack(battle)
	if not active_stack.is_empty():
		_record_event(
			battle,
			"Round %d begins. %s [%s] has the initiative." % [
				int(battle.get("round", 1)),
				_stack_label(active_stack),
				_side_label(String(active_stack.get("side", ""))),
			]
		)

static func _sorted_turn_order(battle: Dictionary) -> Array:
	var candidates = []
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary) or _alive_count(stack) <= 0:
			continue
		candidates.append(String(stack.get("battle_id", "")))

	var sorted = []
	while not candidates.is_empty():
		var best_index = 0
		for index in range(1, candidates.size()):
			if _compare_stack_order(battle, candidates[index], candidates[best_index]):
				best_index = index
		sorted.append(candidates[best_index])
		candidates.remove_at(best_index)
	return sorted

static func _compare_stack_order(battle: Dictionary, lhs_id: String, rhs_id: String) -> bool:
	var lhs = _get_stack_by_id(battle, lhs_id)
	var rhs = _get_stack_by_id(battle, rhs_id)
	var lhs_score = _stack_initiative_total(lhs, battle)
	var rhs_score = _stack_initiative_total(rhs, battle)
	if String(battle.get("terrain", "")) == "mire":
		lhs_score -= 1
		rhs_score -= 1
	if lhs_score == rhs_score:
		var lhs_speed = int(lhs.get("speed", 0))
		var rhs_speed = int(rhs.get("speed", 0))
		if lhs_speed == rhs_speed:
			return String(lhs.get("side", "")) == "player" and String(rhs.get("side", "")) != "player"
		return lhs_speed > rhs_speed
	return lhs_score > rhs_score

static func _advance_to_next_alive(battle: Dictionary, start_index: int) -> String:
	var turn_order = battle.get("turn_order", [])
	if not (turn_order is Array):
		return ""
	var index = max(0, start_index)
	while index < turn_order.size():
		var battle_id = String(turn_order[index])
		var stack = _get_stack_by_id(battle, battle_id)
		if not stack.is_empty() and _alive_count(stack) > 0:
			battle["turn_index"] = index
			return battle_id
		index += 1
	return ""

static func _assign_default_target(battle: Dictionary) -> void:
	var active_stack = get_active_stack(battle)
	if active_stack.is_empty():
		battle["selected_target_id"] = ""
		return
	var target_side = "enemy" if String(active_stack.get("side", "")) == "player" else "player"
	var targets = _alive_stacks_for_side(battle, target_side)
	battle["selected_target_id"] = String(targets[0].get("battle_id", "")) if not targets.is_empty() else ""

static func _calculate_damage(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	rng: RandomNumberGenerator,
	is_ranged: bool,
	is_retaliation: bool = false,
	attack_distance: int = -1
) -> int:
	var attacker_count = max(1, _alive_count(attacker))
	var base_roll = rng.randi_range(int(attacker.get("min_damage", 1)), max(int(attacker.get("min_damage", 1)), int(attacker.get("max_damage", 1))))
	var base_damage = attacker_count * base_roll
	var modifier = _damage_modifier(attacker, defender, battle, is_ranged, is_retaliation, attack_distance)
	return max(1, int(round(base_damage * modifier)))

static func _damage_modifier(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	is_retaliation: bool = false,
	attack_distance: int = -1
) -> float:
	var attack_bonus = int(_hero_payload_for_side(battle, String(attacker.get("side", ""))).get("attack", 0))
	var defense_bonus = int(_hero_payload_for_side(battle, String(defender.get("side", ""))).get("defense", 0))
	var attack_stat = _stack_attack_total(attacker, battle) + attack_bonus
	var defense_stat = _stack_defense_total(defender, battle) + defense_bonus
	if bool(defender.get("defending", false)):
		defense_stat += 2

	var modifier = 1.0 + (clampf(float(attack_stat - defense_stat), -8.0, 8.0) * 0.05)
	var resolved_distance = int(battle.get("distance", 1)) if attack_distance < 0 else attack_distance
	if is_ranged and String(battle.get("terrain", "")) == "forest":
		modifier *= 0.8
	if is_ranged and resolved_distance == 0:
		modifier *= 0.6
	if not is_ranged and String(battle.get("terrain", "")) == "mire":
		modifier *= 0.9
	if is_retaliation:
		modifier *= 0.9
	modifier *= _cohesion_damage_modifier(attacker, defender, battle, is_ranged, is_retaliation)
	modifier *= _ability_damage_modifier(attacker, defender, battle, is_ranged, is_retaliation, resolved_distance)
	modifier *= _terrain_tag_damage_modifier(attacker, defender, battle, is_ranged, resolved_distance)
	modifier *= _faction_damage_modifier(attacker, defender, battle, is_ranged, resolved_distance)
	modifier *= _commander_damage_modifier(attacker, defender, battle, is_ranged, resolved_distance)
	modifier *= float(_hero_payload_for_side(battle, String(attacker.get("side", ""))).get("damage_multiplier", 1.0))
	return modifier

static func _damage_range_preview(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	is_retaliation: bool = false,
	attack_distance: int = -1
) -> Dictionary:
	if attacker.is_empty() or defender.is_empty():
		return {}
	var attacker_count = _alive_count(attacker)
	if attacker_count <= 0:
		return {}
	var min_roll = int(attacker.get("min_damage", 1))
	var max_roll = max(min_roll, int(attacker.get("max_damage", 1)))
	var modifier = _damage_modifier(attacker, defender, battle, is_ranged, is_retaliation, attack_distance)
	var min_damage = max(1, int(round(float(attacker_count * min_roll) * modifier)))
	var max_damage = max(min_damage, int(round(float(attacker_count * max_roll) * modifier)))
	var losses = _unit_loss_range(defender, min_damage, max_damage)
	return {
		"min_damage": min_damage,
		"max_damage": max_damage,
		"min_units": int(losses.get("min_units", 0)),
		"max_units": int(losses.get("max_units", 0)),
	}

static func _unit_loss_range(defender: Dictionary, min_damage: int, max_damage: int) -> Dictionary:
	if defender.is_empty():
		return {"min_units": 0, "max_units": 0}
	var total_health = max(0, int(defender.get("total_health", 0)))
	var unit_hp = max(1, int(defender.get("unit_hp", 1)))
	var before = _alive_count(defender)
	var after_min = int(ceil(float(max(0, total_health - min_damage)) / float(unit_hp)))
	var after_max = int(ceil(float(max(0, total_health - max_damage)) / float(unit_hp)))
	return {
		"min_units": max(0, before - after_min),
		"max_units": max(0, before - after_max),
	}

static func _damage_preview_text(preview: Dictionary) -> String:
	if preview.is_empty():
		return "no clean damage"
	var min_damage = int(preview.get("min_damage", 0))
	var max_damage = int(preview.get("max_damage", min_damage))
	var min_units = int(preview.get("min_units", 0))
	var max_units = int(preview.get("max_units", min_units))
	var damage_text = "%d damage" % min_damage if min_damage == max_damage else "%d-%d damage" % [min_damage, max_damage]
	if max_units <= 0:
		return damage_text
	var unit_text = "%d unit" % min_units if min_units == max_units else "%d-%d units" % [min_units, max_units]
	return "%s (%s)" % [damage_text, unit_text]

static func _retaliation_range_preview(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	attack_distance: int,
	attack_preview: Dictionary
) -> Dictionary:
	if attack_preview.is_empty():
		return {}
	var low_state = defender.duplicate(true)
	low_state["total_health"] = max(0, int(defender.get("total_health", 0)) - int(attack_preview.get("max_damage", 0)))
	var high_state = defender.duplicate(true)
	high_state["total_health"] = max(0, int(defender.get("total_health", 0)) - int(attack_preview.get("min_damage", 0)))
	var low_preview = _damage_range_preview(low_state, attacker, battle, false, true, attack_distance)
	var high_preview = _damage_range_preview(high_state, attacker, battle, false, true, attack_distance)
	if low_preview.is_empty() and high_preview.is_empty():
		return {}
	var min_damage = int(low_preview.get("min_damage", high_preview.get("min_damage", 0)))
	var max_damage = int(high_preview.get("max_damage", low_preview.get("max_damage", min_damage)))
	var losses = _unit_loss_range(attacker, min_damage, max_damage)
	return {
		"min_damage": min_damage,
		"max_damage": max_damage,
		"min_units": int(losses.get("min_units", 0)),
		"max_units": int(losses.get("max_units", 0)),
	}

static func _apply_damage_to_stack(battle: Dictionary, battle_id: String, damage: int) -> void:
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			stack["total_health"] = max(0, int(stack.get("total_health", 0)) - max(0, damage))
			stacks[index] = stack
			break
	battle["stacks"] = stacks

static func _consume_retaliation(battle: Dictionary, battle_id: String) -> void:
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			stack["retaliations_left"] = max(0, int(stack.get("retaliations_left", 0)) - 1)
			stacks[index] = stack
			break
	battle["stacks"] = stacks

static func _consume_shot(battle: Dictionary, battle_id: String) -> void:
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			stack["shots_remaining"] = max(0, int(stack.get("shots_remaining", 0)) - 1)
			stacks[index] = stack
			break
	battle["stacks"] = stacks

static func _set_stack_defending(battle: Dictionary, battle_id: String) -> void:
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			stack["defending"] = true
			stacks[index] = stack
			break
	battle["stacks"] = stacks

static func _apply_advance_pressure(battle: Dictionary, battle_id: String) -> String:
	var stack = _get_stack_by_id(battle, battle_id)
	if stack.is_empty() or _alive_count(stack) <= 0:
		return ""
	var side = String(stack.get("side", ""))
	var momentum_gain = 1 if not bool(stack.get("ranged", false)) else 0
	var hit_obstruction = false
	if _hero_has_trait(battle, String(stack.get("side", "")), "vanguard") and not bool(stack.get("ranged", false)):
		momentum_gain += 1
	if _hero_has_trait(battle, String(stack.get("side", "")), "ambusher") and _battle_has_any_tags(battle, ["ambush_cover"]) and not bool(stack.get("ranged", false)):
		momentum_gain += 1
	if _battle_has_tag(battle, "open_lane") and (not bool(stack.get("ranged", false)) or _hero_has_trait(battle, String(stack.get("side", "")), "artillerist")):
		momentum_gain += 1
	if _side_controls_field_objective_type(battle, side, "obstruction_line") and not bool(stack.get("ranged", false)):
		momentum_gain += 1
	if _side_controls_field_objective_type(battle, _opposing_side(side), "obstruction_line"):
		hit_obstruction = true
		momentum_gain = max(0, momentum_gain - 1)
		if not bool(stack.get("ranged", false)) and not (
			_has_ability(stack, "reach")
			or _has_ability(stack, "brace")
			or _has_ability(stack, "formation_guard")
		):
			_adjust_stack_cohesion(battle, battle_id, -1)
	_adjust_stack_momentum(battle, battle_id, momentum_gain)
	var updated = _get_stack_by_id(battle, battle_id)
	var notes = []
	if hit_obstruction:
		notes.append("%s hits the obstruction line." % _stack_label(updated))
	if _stack_momentum_total(updated, battle) >= 3:
		notes.append("%s surges into the fight." % _stack_label(updated))
	return " ".join(notes)

static func _apply_defend_pressure(battle: Dictionary, battle_id: String) -> String:
	var stack = _get_stack_by_id(battle, battle_id)
	if stack.is_empty() or _alive_count(stack) <= 0:
		return ""
	var cohesion_gain = 1
	var brace = _ability_by_id(stack, "brace")
	if not brace.is_empty():
		cohesion_gain += max(0, int(brace.get("defending_cohesion_bonus", 0)))
	var formation_guard = _ability_by_id(stack, "formation_guard")
	if not formation_guard.is_empty():
		cohesion_gain += max(0, int(formation_guard.get("defending_cohesion_bonus", 0)))
	if _hero_has_trait(battle, String(stack.get("side", "")), "linekeeper"):
		cohesion_gain += 1
	if _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not bool(stack.get("ranged", false)):
		cohesion_gain += 1
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "cover_line"):
		cohesion_gain += 1
	if _side_controls_field_objective_type(battle, String(stack.get("side", "")), "obstruction_line") and not bool(stack.get("ranged", false)):
		cohesion_gain += 1
	_adjust_stack_cohesion(battle, battle_id, cohesion_gain)
	_adjust_stack_momentum(battle, battle_id, -1)
	var updated = _get_stack_by_id(battle, battle_id)
	if _stack_cohesion_total(updated, battle) >= 8:
		return "%s steadies the line." % _stack_label(updated)
	return ""

static func _apply_stack_effect(battle: Dictionary, battle_id: String, effect_payload: Variant) -> void:
	if not (effect_payload is Dictionary):
		return
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary) or String(stack.get("battle_id", "")) != battle_id:
			continue
		stack = SpellRulesScript.normalize_stack_effects(stack)
		var effects = stack.get("effects", [])
		var effect_id = String(effect_payload.get("effect_id", ""))
		var kind = String(effect_payload.get("kind", ""))
		for effect_index in range(effects.size() - 1, -1, -1):
			var existing = effects[effect_index]
			if not (existing is Dictionary):
				continue
			var same_effect_id = effect_id != "" and String(existing.get("effect_id", "")) == effect_id
			var same_legacy_kind = effect_id == "" and kind != "" and String(existing.get("kind", "")) == kind
			if same_effect_id or same_legacy_kind:
				effects.remove_at(effect_index)
		effects.append(effect_payload.duplicate(true))
		stack["effects"] = effects
		stacks[index] = stack
		break
	battle["stacks"] = stacks

static func _can_make_melee_attack(stack: Dictionary, battle: Dictionary) -> bool:
	var distance = int(battle.get("distance", 1))
	if distance <= 0:
		return true
	return distance == 1 and _has_ability(stack, "reach")

static func _can_make_retaliation(stack: Dictionary, attack_distance: int) -> bool:
	if attack_distance <= 0:
		return true
	return attack_distance == 1 and _has_ability(stack, "reach")

static func _apply_attack_ability_effects(
	battle: Dictionary,
	attacker: Dictionary,
	defender: Dictionary,
	is_ranged: bool,
	attack_distance: int
) -> Array:
	var messages = []
	if defender.is_empty() or _alive_count(defender) <= 0:
		return messages
	if not is_ranged and attack_distance > 1:
		return messages

	var harry = _ability_by_id(attacker, "harry")
	if not harry.is_empty() and is_ranged:
		_apply_stack_effect(
			battle,
			String(defender.get("battle_id", "")),
			_status_effect_from_ability(harry, battle)
		)
		messages.append("%s is %s." % [
			_stack_label(defender),
			String(harry.get("status_label", "Harried")).to_lower(),
		])
	return messages

static func _apply_retaliation_ability_effects(
	battle: Dictionary,
	retaliator: Dictionary,
	attacker: Dictionary
) -> Array:
	var messages = []
	if attacker.is_empty() or _alive_count(attacker) <= 0:
		return messages
	var brace = _ability_by_id(retaliator, "brace")
	if brace.is_empty() or not bool(retaliator.get("defending", false)):
		return messages
	_apply_stack_effect(
		battle,
		String(attacker.get("battle_id", "")),
		_status_effect_from_ability(brace, battle)
	)
	messages.append("%s is %s." % [
		_stack_label(attacker),
		String(brace.get("status_label", "Staggered")).to_lower(),
	])
	return messages

static func _status_effect_from_ability(ability: Dictionary, battle: Dictionary) -> Dictionary:
	return SpellRulesScript.build_battle_effect(
		String(ability.get("status_id", "")),
		String(ability.get("status_label", "Status")),
		ability.get("modifiers", {}),
		int(ability.get("duration_rounds", 1)),
		battle,
		"ability",
		String(ability.get("id", ""))
	)

static func _ability_damage_modifier(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	is_retaliation: bool,
	attack_distance: int
) -> float:
	var modifier = 1.0
	var reach = _ability_by_id(attacker, "reach")
	if not is_ranged and attack_distance == 1 and not reach.is_empty():
		modifier *= float(reach.get("distance_one_multiplier", 1.0))

	var brace = _ability_by_id(attacker, "brace")
	if is_retaliation and bool(attacker.get("defending", false)) and not brace.is_empty():
		modifier *= float(brace.get("retaliation_multiplier", 1.0))

	var backstab = _ability_by_id(attacker, "backstab")
	if not backstab.is_empty() and SpellRulesScript.has_any_effect_ids(defender, battle, backstab.get("status_ids", [])):
		modifier *= float(backstab.get("damage_multiplier", 1.0))
	if not backstab.is_empty() and _health_ratio(defender) <= float(backstab.get("health_threshold_ratio", 0.0)):
		modifier *= float(backstab.get("threshold_damage_multiplier", 1.0))

	var volley = _ability_by_id(attacker, "volley")
	if is_ranged and not volley.is_empty() and attack_distance >= int(volley.get("min_distance", 1)):
		modifier *= float(volley.get("damage_multiplier", 1.0))
	if is_ranged and not volley.is_empty() and SpellRulesScript.has_any_effect_ids(defender, battle, volley.get("status_ids", [])):
		modifier *= float(volley.get("status_damage_multiplier", 1.0))
	if is_ranged and not volley.is_empty() and _side_defending_count(battle, String(attacker.get("side", ""))) > 0:
		modifier *= float(volley.get("ally_defending_multiplier", 1.0))

	var formation_guard = _ability_by_id(attacker, "formation_guard")
	if not formation_guard.is_empty() and SpellRulesScript.has_effect_id(defender, battle, STATUS_STAGGERED):
		modifier *= float(formation_guard.get("staggered_damage_multiplier", 1.0))

	var harry = _ability_by_id(attacker, "harry")
	if is_ranged and not harry.is_empty() and _health_ratio(defender) <= float(harry.get("wounded_threshold_ratio", 0.0)):
		modifier *= float(harry.get("wounded_damage_multiplier", 1.0))

	var bloodrush = _ability_by_id(attacker, "bloodrush")
	if not bloodrush.is_empty() and _health_ratio(defender) <= float(bloodrush.get("wounded_threshold_ratio", 0.0)):
		modifier *= float(bloodrush.get("wounded_damage_multiplier", 1.0))
	if not bloodrush.is_empty() and SpellRulesScript.has_any_effect_ids(defender, battle, bloodrush.get("status_ids", [])):
		modifier *= float(bloodrush.get("status_damage_multiplier", 1.0))

	var shielding = _ability_by_id(defender, "shielding")
	if is_ranged and not shielding.is_empty():
		modifier *= float(shielding.get("ranged_damage_multiplier", 1.0))
	var attacking_shielding = _ability_by_id(attacker, "shielding")
	if not is_ranged and not attacking_shielding.is_empty() and attack_distance <= 0:
		modifier *= float(attacking_shielding.get("engaged_damage_multiplier", 1.0))
	if not is_ranged and not attacking_shielding.is_empty() and SpellRulesScript.has_effect_id(defender, battle, STATUS_HARRIED):
		modifier *= float(attacking_shielding.get("harried_damage_multiplier", 1.0))

	return modifier

static func _faction_damage_modifier(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	attack_distance: int
) -> float:
	var modifier = 1.0
	var faction_id = String(attacker.get("faction_id", ""))
	var side = String(attacker.get("side", ""))
	var side_defending_count = _side_defending_count(battle, side)
	match faction_id:
		"faction_embercourt":
			if is_ranged and side_defending_count > 0:
				modifier *= 1.08
				if _side_has_ability(battle, side, "formation_guard"):
					modifier *= _side_max_ability_float(
						battle,
						side,
						"formation_guard",
						"ally_ranged_damage_multiplier",
						1.0
					)
			if SpellRulesScript.has_effect_id(defender, battle, STATUS_STAGGERED):
				modifier *= 1.08
			if int(battle.get("round", 1)) >= 3 and _side_has_role_mix(battle, side):
				modifier *= 1.06 if _side_has_ability(battle, side, "formation_guard") else 1.04
		"faction_mireclaw":
			var wounded_count = _enemy_wounded_count(battle, side)
			if wounded_count > 0:
				modifier *= 1.0 + (float(min(wounded_count, 3)) * 0.04)
			if SpellRulesScript.has_effect_id(defender, battle, STATUS_HARRIED):
				modifier *= 1.08
			if not is_ranged and int(battle.get("round", 1)) >= 3 and attack_distance <= 0:
				modifier *= 1.0 + (float(min(wounded_count, 2)) * 0.03)
		"faction_sunvault":
			var positive_effect_count = _side_positive_effect_count(battle, side)
			if _stack_has_positive_effect(attacker, battle):
				modifier *= 1.08
				if _battle_has_any_tags(battle, ["elevated_fire", "fortified_line"]):
					modifier *= 1.04
			if positive_effect_count >= 2:
				modifier *= 1.0 + (float(min(positive_effect_count, 3)) * 0.03)
			if SpellRulesScript.has_effect_id(defender, battle, STATUS_STAGGERED):
				modifier *= 1.05
			if is_ranged and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]) and positive_effect_count > 0:
				modifier *= 1.04
	return modifier

static func _terrain_tag_damage_modifier(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	attack_distance: int
) -> float:
	var modifier = 1.0
	if _battle_has_tag(battle, "elevated_fire") and is_ranged and attack_distance > 0:
		modifier *= 1.1
	if _battle_has_tag(battle, "open_lane") and is_ranged and attack_distance > 0:
		modifier *= 1.06
	if _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]):
		if not is_ranged and attack_distance <= 1 and (_has_ability(attacker, "reach") or _has_ability(attacker, "brace") or _has_ability(attacker, "formation_guard")):
			modifier *= 1.08
		elif is_ranged and attack_distance > 0:
			modifier *= 0.92
	if _battle_has_tag(battle, "ambush_cover"):
		if not is_ranged and int(battle.get("round", 1)) <= 2:
			modifier *= 1.08
		elif is_ranged and attack_distance > 0:
			modifier *= 0.94
	if _battle_has_tag(battle, "bog_channels") and (
		_has_ability(attacker, "harry")
		or _has_ability(attacker, "backstab")
		or _has_ability(attacker, "bloodrush")
		or SpellRulesScript.has_effect_id(defender, battle, STATUS_HARRIED)
	):
		modifier *= 1.08
	if _battle_has_tag(battle, "fog_bank") and is_ranged and attack_distance > 0:
		modifier *= 0.88
	return modifier

static func _commander_damage_modifier(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	attack_distance: int
) -> float:
	var modifier = 1.0
	var side = String(attacker.get("side", ""))
	if _hero_has_trait(battle, side, "artillerist") and is_ranged and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
		modifier *= 1.06
	if _hero_has_trait(battle, side, "linekeeper") and is_ranged and _side_defending_count(battle, side) > 0:
		modifier *= 1.05
	if _hero_has_trait(battle, side, "packhunter") and (
		_health_ratio(defender) <= 0.75
		or SpellRulesScript.has_effect_id(defender, battle, STATUS_HARRIED)
		or SpellRulesScript.has_effect_id(defender, battle, STATUS_STAGGERED)
	):
		modifier *= 1.06
	if _hero_has_trait(battle, side, "bogwise") and (_battle_has_tag(battle, "bog_channels") or String(battle.get("terrain", "")) == "mire") and (
		_has_ability(attacker, "harry")
		or _has_ability(attacker, "backstab")
		or _has_ability(attacker, "bloodrush")
	):
		modifier *= 1.06
	if _hero_has_trait(battle, side, "vanguard") and not is_ranged and (int(battle.get("round", 1)) <= 2 or _battle_has_tag(battle, "open_lane")) and attack_distance <= 1:
		modifier *= 1.06
	if _hero_has_trait(battle, side, "ambusher") and not is_ranged and (String(battle.get("terrain", "")) == "forest" or _battle_has_tag(battle, "ambush_cover")) and int(battle.get("round", 1)) <= 2:
		modifier *= 1.06
	modifier *= _field_objective_commander_modifier(attacker, defender, battle)
	return modifier

static func _ability_by_id(stack: Dictionary, ability_id: String) -> Dictionary:
	if ability_id == "":
		return {}
	for ability in stack.get("abilities", []):
		if ability is Dictionary and String(ability.get("id", "")) == ability_id:
			return ability
	return {}

static func _has_ability(stack: Dictionary, ability_id: String) -> bool:
	return not _ability_by_id(stack, ability_id).is_empty()

static func _side_ability_payloads(battle: Dictionary, side: String, ability_id: String) -> Array:
	var payloads = []
	for stack in _alive_stacks_for_side(battle, side):
		var ability = _ability_by_id(stack, ability_id)
		if not ability.is_empty():
			payloads.append(ability)
	return payloads

static func _side_has_ability(battle: Dictionary, side: String, ability_id: String) -> bool:
	return not _side_ability_payloads(battle, side, ability_id).is_empty()

static func _battle_has_tag(battle: Dictionary, tag: String) -> bool:
	if tag == "":
		return false
	for value in battle.get("battlefield_tags", []):
		if String(value) == tag:
			return true
	return false

static func _battle_has_any_tags(battle: Dictionary, tags: Array) -> bool:
	for tag_value in tags:
		if _battle_has_tag(battle, String(tag_value)):
			return true
	return false

static func _capital_front_anchor_side(battle: Dictionary) -> String:
	if _is_town_defense_context(battle.get("context", {})):
		return "player"
	if _battle_has_any_tags(battle, ["fortress_lane", "reserve_wave", "battery_nest", "wall_pressure"]):
		return "enemy"
	return ""

static func _capital_front_assault_side(battle: Dictionary) -> String:
	var anchor_side = _capital_front_anchor_side(battle)
	if anchor_side == "player":
		return "enemy"
	if anchor_side == "enemy":
		return "player"
	return ""

static func _stack_is_anchor_side(stack: Dictionary, battle: Dictionary) -> bool:
	return String(stack.get("side", "")) == _capital_front_anchor_side(battle)

static func _stack_is_assault_side(stack: Dictionary, battle: Dictionary) -> bool:
	return String(stack.get("side", "")) == _capital_front_assault_side(battle)

static func _hero_has_trait(battle: Dictionary, side: String, trait_id: String) -> bool:
	if trait_id == "":
		return false
	for value in _hero_payload_for_side(battle, side).get("battle_traits", []):
		if String(value) == trait_id:
			return true
	return false

static func _side_max_ability_float(
	battle: Dictionary,
	side: String,
	ability_id: String,
	key: String,
	default_value: float = 1.0
) -> float:
	var best = default_value
	for ability in _side_ability_payloads(battle, side, ability_id):
		best = max(best, float(ability.get(key, default_value)))
	return best

static func _side_max_ability_int(battle: Dictionary, side: String, ability_id: String, key: String) -> int:
	var best = 0
	for ability in _side_ability_payloads(battle, side, ability_id):
		best = max(best, int(ability.get(key, 0)))
	return best

static func _normalize_unit_abilities(value: Variant) -> Array:
	var abilities = []
	var seen = {}
	if not (value is Array):
		return abilities
	for entry in value:
		if not (entry is Dictionary):
			continue
		var ability_id = String(entry.get("id", ""))
		if ability_id == "" or seen.has(ability_id):
			continue
		var normalized = {}
		match ability_id:
			"reach":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Reach")),
					"description": String(entry.get("description", "")),
					"distance_one_multiplier": clampf(float(entry.get("distance_one_multiplier", 1.0)), 0.5, 1.5),
				}
			"brace":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Brace")),
					"description": String(entry.get("description", "")),
					"retaliation_multiplier": clampf(float(entry.get("retaliation_multiplier", 1.0)), 1.0, 2.0),
					"defending_cohesion_bonus": max(0, int(entry.get("defending_cohesion_bonus", 0))),
					"status_id": String(entry.get("status_id", STATUS_STAGGERED)),
					"status_label": String(entry.get("status_label", "Staggered")),
					"duration_rounds": max(1, int(entry.get("duration_rounds", 1))),
					"modifiers": _normalize_ability_modifiers(entry.get("modifiers", {"initiative": -2})),
				}
			"harry":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Harry")),
					"description": String(entry.get("description", "")),
					"status_id": String(entry.get("status_id", STATUS_HARRIED)),
					"status_label": String(entry.get("status_label", "Harried")),
					"duration_rounds": max(1, int(entry.get("duration_rounds", 2))),
					"modifiers": _normalize_ability_modifiers(entry.get("modifiers", {"defense": -1, "initiative": -1})),
					"momentum_gain": max(0, int(entry.get("momentum_gain", 0))),
					"wounded_threshold_ratio": clampf(float(entry.get("wounded_threshold_ratio", 0.0)), 0.0, 1.0),
					"wounded_damage_multiplier": clampf(float(entry.get("wounded_damage_multiplier", 1.0)), 1.0, 2.0),
				}
			"backstab":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Backstab")),
					"description": String(entry.get("description", "")),
					"damage_multiplier": clampf(float(entry.get("damage_multiplier", 1.0)), 1.0, 2.0),
					"momentum_gain": max(0, int(entry.get("momentum_gain", 0))),
					"status_ids": _normalize_string_array(entry.get("status_ids", [STATUS_HARRIED, STATUS_STAGGERED])),
					"health_threshold_ratio": clampf(float(entry.get("health_threshold_ratio", 0.0)), 0.0, 1.0),
					"threshold_damage_multiplier": clampf(float(entry.get("threshold_damage_multiplier", 1.0)), 1.0, 2.0),
				}
			"shielding":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Shielding")),
					"description": String(entry.get("description", "")),
					"cohesion_hold_bonus": max(0, int(entry.get("cohesion_hold_bonus", 0))),
					"ranged_damage_multiplier": clampf(float(entry.get("ranged_damage_multiplier", 1.0)), 0.25, 1.0),
					"engaged_damage_multiplier": clampf(float(entry.get("engaged_damage_multiplier", 1.0)), 1.0, 2.0),
					"harried_damage_multiplier": clampf(float(entry.get("harried_damage_multiplier", 1.0)), 1.0, 2.0),
				}
			"volley":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Volley")),
					"description": String(entry.get("description", "")),
					"damage_multiplier": clampf(float(entry.get("damage_multiplier", 1.0)), 1.0, 2.0),
					"min_distance": max(1, int(entry.get("min_distance", 1))),
					"status_ids": _normalize_string_array(entry.get("status_ids", [])),
					"status_damage_multiplier": clampf(float(entry.get("status_damage_multiplier", 1.0)), 1.0, 2.0),
					"ally_defending_multiplier": clampf(float(entry.get("ally_defending_multiplier", 1.0)), 1.0, 2.0),
				}
			"formation_guard":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Formation Guard")),
					"description": String(entry.get("description", "")),
					"ally_ranged_damage_multiplier": clampf(float(entry.get("ally_ranged_damage_multiplier", 1.0)), 1.0, 2.0),
					"ally_ranged_initiative_bonus": max(0, int(entry.get("ally_ranged_initiative_bonus", 0))),
					"ally_cohesion_bonus": max(0, int(entry.get("ally_cohesion_bonus", 0))),
					"defending_cohesion_bonus": max(0, int(entry.get("defending_cohesion_bonus", 0))),
					"defending_initiative_bonus": max(0, int(entry.get("defending_initiative_bonus", 0))),
					"staggered_damage_multiplier": clampf(float(entry.get("staggered_damage_multiplier", 1.0)), 1.0, 2.0),
				}
			"bloodrush":
				normalized = {
					"id": ability_id,
					"name": String(entry.get("name", "Bloodrush")),
					"description": String(entry.get("description", "")),
					"wounded_threshold_ratio": clampf(float(entry.get("wounded_threshold_ratio", 0.0)), 0.0, 1.0),
					"wounded_damage_multiplier": clampf(float(entry.get("wounded_damage_multiplier", 1.0)), 1.0, 2.0),
					"status_ids": _normalize_string_array(entry.get("status_ids", [STATUS_HARRIED, STATUS_STAGGERED])),
					"status_damage_multiplier": clampf(float(entry.get("status_damage_multiplier", 1.0)), 1.0, 2.0),
					"wounded_initiative_bonus": max(0, int(entry.get("wounded_initiative_bonus", 0))),
					"max_initiative_bonus": max(0, int(entry.get("max_initiative_bonus", 0))),
					"momentum_gain": max(0, int(entry.get("momentum_gain", 0))),
					"kill_momentum_gain": max(0, int(entry.get("kill_momentum_gain", 0))),
					"late_round_initiative_bonus": max(0, int(entry.get("late_round_initiative_bonus", 0))),
				}
			_:
				continue
		abilities.append(normalized)
		seen[ability_id] = true
	return abilities

static func _normalize_ability_modifiers(value: Variant) -> Dictionary:
	var modifiers = {}
	if value is Dictionary:
		for key in value.keys():
			var modifier_key = String(key)
			if modifier_key == "":
				continue
			modifiers[modifier_key] = int(value[key])
	return modifiers

static func _normalize_string_array(value: Variant) -> Array:
	var normalized = []
	if value is Array:
		for entry in value:
			var text = String(entry)
			if text != "" and text not in normalized:
				normalized.append(text)
	return normalized

static func _stack_ability_summary(stack: Dictionary) -> String:
	var names = []
	for ability in stack.get("abilities", []):
		if ability is Dictionary:
			var name = String(ability.get("name", ability.get("id", "")))
			if name != "":
				names.append(name)
	return ", ".join(names)

static func _sync_player_force_from_battle(session: SessionStateStoreScript.SessionData) -> void:
	if session == null or session.battle.is_empty():
		return
	var context = session.battle.get("context", {})
	var commander_source = session.battle.get("player_commander_source", {})
	var commander_type = String(commander_source.get("type", ""))
	var commander_state = _player_commander_state(session).duplicate(true)
	if commander_type in ["active_hero", "town_hero"]:
		commander_state["army"] = {
			"id": String(commander_state.get("army", {}).get("id", "%s_army" % String(commander_state.get("id", "")))),
			"name": String(commander_state.get("army", {}).get("name", "Field Army")),
			"stacks": _battle_survivor_stacks(
				session,
				"player",
				{
					"source_type": "hero_army",
					"hero_id": String(commander_source.get("hero_id", "")),
				}
			),
		}
		_set_player_hero_state(session, commander_state, String(commander_source.get("hero_id", "")))

	if _is_town_defense_context(context):
		var town_result = _find_town_by_placement(session, String(context.get("town_placement_id", "")))
		if int(town_result.get("index", -1)) >= 0:
			var towns = session.overworld.get("towns", [])
			var town = town_result.get("town", {})
			town["garrison"] = _battle_survivor_stacks(
				session,
				"player",
				{
					"source_type": "town_garrison",
					"town_placement_id": String(context.get("town_placement_id", "")),
				}
			)
			towns[int(town_result.get("index", -1))] = town
			session.overworld["towns"] = towns
		return

	var army = session.overworld.get("army", {})
	army["stacks"] = _battle_survivor_stacks(
		session,
		"player",
		{
			"source_type": "hero_army",
			"hero_id": String(commander_source.get("hero_id", session.overworld.get("active_hero_id", ""))),
		}
	)
	session.overworld["army"] = army

static func _sync_enemy_force_from_battle(session: SessionStateStoreScript.SessionData, encounter_resolved: bool) -> void:
	if session == null or session.battle.is_empty():
		return
	var context = session.battle.get("context", {})
	if _is_town_assault_context(context):
		var town_result = _find_town_by_placement(session, String(context.get("town_placement_id", "")))
		if int(town_result.get("index", -1)) < 0:
			return
		var towns = session.overworld.get("towns", [])
		var town = town_result.get("town", {})
		town["garrison"] = _battle_survivor_stacks(
			session,
			"enemy",
			{
				"source_type": "town_garrison",
				"town_placement_id": String(context.get("town_placement_id", "")),
			}
		)
		towns[int(town_result.get("index", -1))] = town
		session.overworld["towns"] = towns
		return
	var encounter_result = _find_encounter_by_key(session, String(session.battle.get("resolved_key", "")))
	if int(encounter_result.get("index", -1)) < 0:
		return
	var encounters = session.overworld.get("encounters", [])
	var encounter = encounter_result.get("encounter", {})
	encounter["enemy_army"] = {
		"id": String(encounter.get("enemy_army", {}).get("id", encounter.get("encounter_id", "encounter_army"))),
		"name": String(encounter.get("enemy_army", {}).get("name", "Raid Host")),
		"stacks": _battle_survivor_stacks(
			session,
			"enemy",
			{
				"source_type": "encounter_army",
				"encounter_key": String(session.battle.get("resolved_key", "")),
			}
		),
	}
	encounters[int(encounter_result.get("index", -1))] = encounter
	session.overworld["encounters"] = encounters
	if encounter_resolved:
		_mark_resolved_encounter(session, String(session.battle.get("resolved_key", "")))

static func _battle_survivor_stacks(session: SessionStateStoreScript.SessionData, side: String, filters: Dictionary = {}) -> Array:
	var survivors = []
	for stack in session.battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		if String(stack.get("side", "")) != side:
			continue
		var count = _alive_count(stack)
		if count <= 0:
			continue
		if filters.has("source_type") and String(stack.get("source_type", "")) != String(filters.get("source_type", "")):
			continue
		if filters.has("hero_id") and String(stack.get("source_hero_id", "")) != String(filters.get("hero_id", "")):
			continue
		if filters.has("town_placement_id") and String(stack.get("source_town_placement_id", "")) != String(filters.get("town_placement_id", "")):
			continue
		if filters.has("encounter_key") and String(stack.get("source_encounter_key", "")) != String(filters.get("encounter_key", "")):
			continue
		survivors.append({"unit_id": String(stack.get("unit_id", "")), "count": count})
	return survivors

static func _award_commander_experience(session: SessionStateStoreScript.SessionData, amount: int) -> Array:
	if amount <= 0 or session == null or session.battle.is_empty():
		return []
	var commander_source = session.battle.get("player_commander_source", {})
	if String(commander_source.get("type", "")) not in ["active_hero", "town_hero"]:
		return []
	var result = HeroProgressionRulesScript.add_experience(_player_commander_state(session), amount)
	session.battle["player_commander_state"] = result.get("hero", _player_commander_state(session))
	session.battle["player_hero"] = _hero_payload_from_state(
		session.battle.get("player_commander_state", {}),
		ArtifactRulesScript.aggregate_bonuses(session.battle.get("player_commander_state", {})),
		session,
		"player"
	)
	return result.get("messages", [])

static func _apply_battle_context_victory(session: SessionStateStoreScript.SessionData) -> String:
	var context = session.battle.get("context", {})
	if _is_town_assault_context(context):
		var town_name = _town_name_from_placement_id(session, String(context.get("town_placement_id", "")))
		var message = OverworldRulesScript.capture_town_by_placement(session, String(context.get("town_placement_id", "")))
		if message == "":
			message = "%s falls to the assault." % (town_name if town_name != "" else "The town")
		var recovery_message = _apply_town_assault_recovery(session, "victory")
		if recovery_message != "":
			message = "%s %s" % [message, recovery_message]
		return message
	if not _is_town_defense_context(context):
		return ""
	_set_enemy_siege_progress(session, String(context.get("trigger_faction_id", "")), 0)
	var town_name = _town_name_from_placement_id(session, String(context.get("town_placement_id", "")))
	var message = "%s repels the assault." % (town_name if town_name != "" else "The town")
	var recovery_message = _apply_town_defense_recovery(session, "victory")
	if recovery_message != "":
		message = "%s %s" % [message, recovery_message]
	return message

static func _apply_battle_context_stalemate(session: SessionStateStoreScript.SessionData) -> String:
	var context = session.battle.get("context", {})
	if _is_town_assault_context(context):
		var town_name = _town_name_from_placement_id(session, String(context.get("town_placement_id", "")))
		var message = "%s holds through the assault and remains hostile." % (
			town_name if town_name != "" else "The town"
		)
		var recovery_message = _apply_town_assault_recovery(session, "stalemate")
		if recovery_message != "":
			message = "%s %s" % [message, recovery_message]
		return message
	if not _is_town_defense_context(context):
		return ""
	var town_name = _town_name_from_placement_id(session, String(context.get("town_placement_id", "")))
	var message = "%s holds through the assault, but the siege is not broken." % (town_name if town_name != "" else "The town")
	var recovery_message = _apply_town_defense_recovery(session, "stalemate")
	if recovery_message != "":
		message = "%s %s" % [message, recovery_message]
	return message

static func _apply_delivery_route_aftermath(session: SessionStateStoreScript.SessionData, outcome: String) -> String:
	if session == null or session.battle.is_empty():
		return ""
	if bool(session.battle.get("delivery_outcome_applied", false)):
		return ""
	var context = session.battle.get("context", {})
	var node_placement_id: String = String(context.get("delivery_node_placement_id", ""))
	if node_placement_id == "":
		return ""
	session.battle["delivery_outcome_applied"] = true
	return String(OverworldRulesScript.apply_delivery_interception_outcome(session, node_placement_id, outcome).get("summary", ""))

static func _finalize_town_defense_loss(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var context = session.battle.get("context", {})
	var messages = []
	var town_name = _town_name_from_placement_id(session, String(context.get("town_placement_id", "")))
	var base_summary := "%s falls after the walls are breached." % town_name if town_name != "" else "The town falls after the walls are breached."
	var commander_source = session.battle.get("player_commander_source", {})
	var defending_hero_id = String(commander_source.get("hero_id", ""))
	_sync_player_force_from_battle(session)
	var enemy_survivors = _battle_survivor_stacks(
		session,
		"enemy",
		{
			"source_type": "encounter_army",
			"encounter_key": String(session.battle.get("resolved_key", "")),
		}
	)
	_capture_town_after_assault(session, String(context.get("town_placement_id", "")), enemy_survivors)
	var recovery_message = _apply_town_defense_recovery(session, "loss")
	_mark_resolved_encounter(session, String(session.battle.get("resolved_key", "")))
	_set_enemy_siege_progress(session, String(context.get("trigger_faction_id", "")), 0)
	messages.append(base_summary)
	_append_nonempty_message(messages, recovery_message)
	_append_nonempty_message(messages, _apply_delivery_route_aftermath(session, "town_lost"))

	var defending_hero = HeroCommandRulesScript.hero_by_id(session, defending_hero_id)
	if not defending_hero.is_empty():
		if bool(defending_hero.get("is_primary", false)):
			var defeat_result = _finalize_primary_defeat(session, "The primary commander is defeated.", "town_lost")
			var report = session.flags.get("last_battle_aftermath", {})
			if report is Dictionary:
				report["summary"] = base_summary
				report["recovery_summary"] = recovery_message
				session.flags["last_battle_aftermath"] = report
			_append_nonempty_message(messages, String(defeat_result.get("message", "")))
			return {"state": "defeat", "message": " ".join(messages)}
		var removal = _remove_hero_by_id_after_defeat(session, defending_hero_id)
		_append_nonempty_message(messages, String(removal.get("message", "")))

	session.flags["last_battle_outcome"] = "town_lost"
	_record_battle_aftermath(
		session,
		"town_lost",
		base_summary,
		{"recovery_summary": recovery_message}
	)
	session.battle = {}
	OverworldRulesScript.refresh_fog_of_war(session)
	var scenario_result = ScenarioRulesScript.evaluate_session(session)
	_append_nonempty_message(messages, String(scenario_result.get("message", "")))
	var final_message = " ".join(messages)
	if session.scenario_status == "in_progress" and final_message != "":
		session.flags["return_notice"] = final_message
	return {
		"state": "defeat" if session.scenario_status != "in_progress" else "town_lost",
		"message": final_message,
	}

static func _apply_town_defense_recovery(session: SessionStateStoreScript.SessionData, outcome: String) -> String:
	var context = session.battle.get("context", {})
	if not _is_town_defense_context(context):
		return ""
	var pressure = _town_defense_recovery_pressure(session, outcome)
	if pressure <= 0:
		return ""
	var source = ""
	match outcome:
		"victory":
			source = "repelled assault"
		"stalemate":
			source = "battered walls"
		"loss":
			source = "breached walls"
	return OverworldRulesScript.apply_town_recovery_pressure(
		session,
		String(context.get("town_placement_id", "")),
		pressure,
		source
	)

static func _town_defense_recovery_pressure(session: SessionStateStoreScript.SessionData, outcome: String) -> int:
	if session == null or session.battle.is_empty():
		return 0
	var context = session.battle.get("context", {})
	var encounter_result = _find_encounter_by_key(session, String(session.battle.get("resolved_key", "")))
	var assault_strength = _army_strength_from_stacks(encounter_result.get("encounter", {}).get("enemy_army", {}).get("stacks", []))
	var pressure = max(1, int(round(float(max(1, assault_strength)) / 180.0)))
	match outcome:
		"stalemate":
			pressure += 1
		"loss":
			pressure += 2
	var town = _find_town_by_placement(session, String(context.get("town_placement_id", ""))).get("town", {})
	match OverworldRulesScript.town_strategic_role(town):
		"capital":
			pressure += 1
		"stronghold":
			pressure += 1
	return clamp(pressure, 1, 6)

static func _apply_town_assault_recovery(session: SessionStateStoreScript.SessionData, outcome: String) -> String:
	var context = session.battle.get("context", {})
	if not _is_town_assault_context(context):
		return ""
	var pressure = _town_assault_recovery_pressure(session, outcome)
	if pressure <= 0:
		return ""
	var source = "stormed walls" if outcome == "victory" else "contested walls"
	return OverworldRulesScript.apply_town_recovery_pressure(
		session,
		String(context.get("town_placement_id", "")),
		pressure,
		source
	)

static func _town_assault_recovery_pressure(session: SessionStateStoreScript.SessionData, outcome: String) -> int:
	if session == null or session.battle.is_empty():
		return 0
	var context = session.battle.get("context", {})
	var town = _find_town_by_placement(session, String(context.get("town_placement_id", ""))).get("town", {})
	var pressure = max(1, int(round(float(max(1, _army_strength_from_stacks(town.get("garrison", [])))) / 220.0)))
	if outcome == "victory":
		pressure += 1
	match OverworldRulesScript.town_strategic_role(town):
		"capital":
			pressure += 1
		"stronghold":
			pressure += 1
	return clamp(pressure, 1, 5)

static func _capture_town_after_assault(session: SessionStateStoreScript.SessionData, town_placement_id: String, enemy_survivors: Array) -> void:
	var town_result = _find_town_by_placement(session, town_placement_id)
	if int(town_result.get("index", -1)) < 0:
		return
	var towns = session.overworld.get("towns", [])
	var town = town_result.get("town", {})
	town["owner"] = "enemy"
	town["garrison"] = enemy_survivors.duplicate(true)
	towns[int(town_result.get("index", -1))] = town
	session.overworld["towns"] = towns

static func _set_player_hero_state(session: SessionStateStoreScript.SessionData, hero_state: Dictionary, hero_id: String) -> void:
	if session == null or hero_id == "":
		return
	var heroes = session.overworld.get("player_heroes", [])
	if not (heroes is Array):
		return
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == hero_id:
			heroes[index] = hero_state.duplicate(true)
			break
	session.overworld["player_heroes"] = heroes
	if String(session.overworld.get("active_hero_id", "")) == hero_id:
		session.overworld["hero"] = hero_state.duplicate(true)
		session.overworld["army"] = hero_state.get("army", {}).duplicate(true) if hero_state.get("army", {}) is Dictionary else {}
		session.overworld["hero_position"] = hero_state.get("position", {}).duplicate(true) if hero_state.get("position", {}) is Dictionary else session.overworld.get("hero_position", {})
		session.overworld["movement"] = hero_state.get("movement", {}).duplicate(true) if hero_state.get("movement", {}) is Dictionary else session.overworld.get("movement", {})

static func _remove_hero_by_id_after_defeat(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	HeroCommandRulesScript.normalize_session(session)
	HeroCommandRulesScript.commit_active_hero(session)
	var removed_hero = HeroCommandRulesScript.hero_by_id(session, hero_id)
	if removed_hero.is_empty():
		return {"ok": false, "message": ""}
	var remaining = []
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and String(hero.get("id", "")) != hero_id:
			remaining.append(hero)
	session.overworld["player_heroes"] = remaining
	if String(session.overworld.get("active_hero_id", "")) == hero_id:
		var next_active_id = String(session.hero_id)
		var found = false
		for hero in remaining:
			if hero is Dictionary and String(hero.get("id", "")) == next_active_id:
				found = true
				break
		if not found and not remaining.is_empty():
			next_active_id = String(remaining[0].get("id", ""))
		session.overworld["active_hero_id"] = next_active_id
		HeroCommandRulesScript._sync_active_hero_mirror(session)
	return {
		"ok": true,
		"message": "%s falls defending the town." % String(removed_hero.get("name", "The hero")),
	}

static func _mark_resolved_encounter(session: SessionStateStoreScript.SessionData, resolved_key: String) -> void:
	if session == null or resolved_key == "":
		return
	var resolved = session.overworld.get("resolved_encounters", [])
	if not (resolved is Array):
		resolved = []
	if resolved_key not in resolved:
		resolved.append(resolved_key)
	session.overworld["resolved_encounters"] = resolved

static func _set_enemy_siege_progress(session: SessionStateStoreScript.SessionData, faction_id: String, progress: int) -> void:
	if session == null or faction_id == "":
		return
	var states = session.overworld.get("enemy_states", [])
	if not (states is Array):
		return
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary):
			continue
		if String(state.get("faction_id", "")) != faction_id:
			continue
		state["siege_progress"] = max(0, progress)
		states[index] = state
		break
	session.overworld["enemy_states"] = states

static func _army_strength_from_stacks(stacks: Variant) -> int:
	var total = 0
	if not (stacks is Array):
		return total
	for stack in stacks:
		if not (stack is Dictionary):
			continue
		var unit = ContentService.get_unit(String(stack.get("unit_id", "")))
		var count = max(0, int(stack.get("count", 0)))
		total += count * max(
			6,
			int(unit.get("hp", 1))
			+ int(unit.get("min_damage", 1))
			+ int(unit.get("max_damage", 1))
			+ (3 if bool(unit.get("ranged", false)) else 0)
		)
	return total

static func _alive_count(stack: Dictionary) -> int:
	var unit_hp = max(1, int(stack.get("unit_hp", 1)))
	return int(ceil(float(max(0, int(stack.get("total_health", 0)))) / float(unit_hp)))

static func _health_ratio(stack: Dictionary) -> float:
	if stack.is_empty():
		return 0.0
	var max_health = max(1, int(stack.get("base_count", 0)) * max(1, int(stack.get("unit_hp", 1))))
	return clampf(float(max(0, int(stack.get("total_health", 0)))) / float(max_health), 0.0, 1.0)

static func _alive_stacks_for_side(battle: Dictionary, side: String) -> Array:
	var alive = []
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("side", "")) == side and _alive_count(stack) > 0:
			alive.append(stack)
	return alive

static func _stack_has_positive_effect(stack: Dictionary, battle: Dictionary) -> bool:
	var current_round = int(battle.get("round", 1))
	for effect in SpellRulesScript.active_effects_for_round(stack, current_round):
		var modifiers = effect.get("modifiers", {})
		if not (modifiers is Dictionary):
			continue
		for modifier_key in ["attack", "defense", "initiative", "cohesion", "momentum"]:
			if int(modifiers.get(modifier_key, 0)) > 0:
				return true
	return false

static func _side_positive_effect_count(battle: Dictionary, side: String) -> int:
	var total = 0
	for stack in _alive_stacks_for_side(battle, side):
		if stack is Dictionary and _stack_has_positive_effect(stack, battle):
			total += 1
	return total

static func _lowest_health_stack(stacks: Array) -> Dictionary:
	var best = {}
	for stack in stacks:
		if not (stack is Dictionary):
			continue
		if best.is_empty() or int(stack.get("total_health", 0)) < int(best.get("total_health", 0)):
			best = stack
	return best

static func _army_totals(battle: Dictionary, side: String) -> Dictionary:
	var totals = {
		"stacks": 0,
		"units": 0,
		"health": 0,
		"ranged_stacks": 0,
	}
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary) or String(stack.get("side", "")) != side:
			continue
		var count = _alive_count(stack)
		if count <= 0:
			continue
		totals["stacks"] = int(totals.get("stacks", 0)) + 1
		totals["units"] = int(totals.get("units", 0)) + count
		totals["health"] = int(totals.get("health", 0)) + int(stack.get("total_health", 0))
		if bool(stack.get("ranged", false)):
			totals["ranged_stacks"] = int(totals.get("ranged_stacks", 0)) + 1
	return totals

static func _battle_context_label(session: SessionStateStoreScript.SessionData, context: Variant) -> String:
	if not (context is Dictionary):
		return "Field engagement"
	if _has_delivery_context(context):
		var target_label := String(context.get("delivery_target_label", "the front"))
		if String(context.get("type", "")) == "town_defense":
			return "Relief defense at %s" % (target_label if target_label != "" else "the walls")
		return "Convoy clash near %s" % (target_label if target_label != "" else "the front")
	if String(context.get("type", "")) == "hero_intercept":
		var hero_name := String(
			HeroCommandRulesScript.hero_by_id(session, String(context.get("target_hero_id", ""))).get("name", "the road")
		)
		return "Interception near %s" % hero_name
	if _is_town_assault_context(context):
		var assault_town_name = _town_name_from_placement_id(session, String(context.get("town_placement_id", "")))
		match String(context.get("town_role", "frontier")):
			"capital":
				return "Capital assault at %s" % (assault_town_name if assault_town_name != "" else "the walls")
			"stronghold":
				return "Stronghold assault at %s" % (assault_town_name if assault_town_name != "" else "the walls")
			_:
				return "Town assault at %s" % (assault_town_name if assault_town_name != "" else "the walls")
	if String(context.get("type", "")) != "town_defense":
		return "Field engagement"
	var town_name = _town_name_from_placement_id(session, String(context.get("town_placement_id", "")))
	match String(context.get("town_role", "frontier")):
		"capital":
			return "Capital defense at %s" % (town_name if town_name != "" else "the walls")
		"stronghold":
			return "Stronghold defense at %s" % (town_name if town_name != "" else "the walls")
		_:
			return "Town defense at %s" % (town_name if town_name != "" else "the walls")

static func _battlefield_identity_summary(battle: Dictionary) -> String:
	var parts = []
	if _has_delivery_context(battle.get("context", {})):
		parts.append("the fight is sitting on a live reinforcement route")
	if _battle_has_tag(battle, "fortress_lane"):
		parts.append("fortress lanes compress the approach")
	if _battle_has_tag(battle, "battery_nest"):
		parts.append("battery nests punish long approaches")
	if _battle_has_tag(battle, "wall_pressure"):
		parts.append("wall pressure favors late breach fighting")
	if _battle_has_tag(battle, "reserve_wave"):
		parts.append("reserve waves matter after the opening exchanges")
	var objective_brief = _field_objective_status_brief(battle)
	if objective_brief != "":
		parts.append(objective_brief.to_lower())
	if parts.is_empty() and String(battle.get("context", {}).get("battlefront_summary", "")) != "":
		return String(battle.get("context", {}).get("battlefront_summary", ""))
	return ", ".join(parts)

static func _distance_label(distance: int) -> String:
	match max(0, distance):
		0:
			return "Lines engaged"
		1:
			return "Closing distance"
		_:
			return "Long approach"

static func _side_label(side: String) -> String:
	return "Enemy" if side == "enemy" else "Player"

static func _commander_state_for_side(battle: Dictionary, side: String) -> Dictionary:
	if side == "enemy":
		return battle.get("enemy_hero", {})
	return battle.get("player_commander_state", {})

static func _commander_role_label(battle: Dictionary, side: String) -> String:
	if side == "enemy":
		return "Enemy commander" if not _commander_state_for_side(battle, side).is_empty() else "Uncommanded host"
	var source = battle.get("player_commander_source", {})
	match String(source.get("type", "")):
		"active_hero":
			return "Field commander"
		"town_hero":
			return "Town defender"
		"town_captain":
			return "Town captain"
		_:
			return "Commander"

static func _pressure_brief(session: SessionStateStoreScript.SessionData) -> String:
	if session == null or session.battle.is_empty():
		return "No pressure data."
	var battle = session.battle
	var objective_pressure = _field_objective_pressure_brief(battle)
	if objective_pressure != "":
		return objective_pressure
	var player_totals = _army_totals(battle, "player")
	var enemy_totals = _army_totals(battle, "enemy")
	var player_health = max(1, int(player_totals.get("health", 0)))
	var enemy_health = max(1, int(enemy_totals.get("health", 0)))
	var rounds_remaining = max(0, int(battle.get("max_rounds", 12)) - int(battle.get("round", 1)) + 1)
	if _side_controls_field_objective_type(battle, "enemy", "cover_line") and _side_controls_field_objective_type(battle, "enemy", "lane_battery") and int(battle.get("distance", 1)) > 0:
		return "Enemy guns are firing from cover and screening their commander."
	if _side_controls_field_objective_type(battle, "enemy", "cover_line") and int(battle.get("distance", 1)) > 0:
		return "Enemy cover lines are still screening the approach."
	if _side_controls_field_objective_type(battle, "player", "cover_line") and int(battle.get("distance", 1)) > 0:
		return "Friendly cover is blunting the opening volleys."
	if _side_controls_field_objective_type(battle, "enemy", "obstruction_line") and int(battle.get("distance", 1)) > 0:
		return "Enemy obstructions are still compressing the approach."
	if _side_controls_field_objective_type(battle, "player", "obstruction_line") and int(battle.get("distance", 1)) > 0:
		return "Friendly hands now own the choke and can tax the enemy push."
	if _battle_has_tag(battle, "battery_nest") and int(battle.get("round", 1)) <= 2 and int(battle.get("distance", 1)) > 0:
		return "Battery lanes are still punishing the approach."
	if _battle_has_tag(battle, "fortress_lane") and int(battle.get("round", 1)) <= 2:
		return "Fortress lanes are compressing the assault into a kill zone."
	if _reserve_wave_is_active_for_side(battle, _capital_front_anchor_side(battle)):
		return "Reserve companies are reaching the line and changing the exchange."
	if _battle_has_tag(battle, "wall_pressure") and int(battle.get("round", 1)) >= 3:
		return "The breach is widening; late melee exchanges will snowball fast."
	if _is_town_defense_context(battle.get("context", {})) and enemy_health > player_health:
		return "The walls are under strain; a collapse here costs the town."
	if _is_town_assault_context(battle.get("context", {})) and enemy_health >= player_health:
		return "The breach is stalling; the town stays hostile unless the wall line breaks."
	if rounds_remaining <= 2:
		return "The clock is tightening; one more slow round risks stalemate."
	if enemy_health <= int(round(float(player_health) * 0.65)):
		return "The enemy line is wavering."
	if player_health <= int(round(float(enemy_health) * 0.65)):
		return "The friendly line is under heavy pressure."
	if int(battle.get("round", 1)) >= 3:
		var player_doctrine = _side_doctrine_summary(battle, "player")
		var enemy_doctrine = _side_doctrine_summary(battle, "enemy")
		if player_doctrine != enemy_doctrine:
			return "%s versus %s is defining the late exchanges." % [player_doctrine, enemy_doctrine]
	return "The exchange is still balanced."

static func _engagement_preview(active_stack: Dictionary, target: Dictionary, battle: Dictionary) -> String:
	if active_stack.is_empty() or target.is_empty():
		return "No engagement forecast."
	if String(active_stack.get("side", "")) == String(target.get("side", "")):
		return "Friendly stack selected."
	if String(active_stack.get("side", "")) == "player":
		var availability = action_availability(battle)
		if bool(availability.get("shoot", false)) and bool(active_stack.get("ranged", false)):
			return "%s can shoot now." % _stack_label(active_stack)
		if bool(availability.get("strike", false)):
			return "%s can strike now." % _stack_label(active_stack)
		return "Advance is needed before %s can be reached." % _stack_label(target)
	return "%s is threatening %s." % [_stack_label(active_stack), _stack_label(target)]

static func _stack_focus_summary(stack: Dictionary, battle: Dictionary, is_active: bool) -> String:
	if stack.is_empty():
		return "No stack is selected."
	var side = String(stack.get("side", ""))
	var lines = [
		"%s [%s]%s" % [
			_stack_label(stack),
			_side_label(side),
			" | Acting now" if is_active else "",
		],
		"Count %d | HP %d | Dmg %d-%d | Speed %d" % [
			_alive_count(stack),
			int(stack.get("total_health", 0)),
			int(stack.get("min_damage", 1)),
			int(stack.get("max_damage", 1)),
			int(stack.get("speed", 1)),
		],
		"Attack %d | Defense %d | Initiative %d" % [
			_stack_attack_total(stack, battle),
			_stack_defense_total(stack, battle),
			_stack_initiative_total(stack, battle),
		],
		"Cohesion %d | Momentum %d%s" % [
			_stack_cohesion_total(stack, battle),
			_stack_momentum_total(stack, battle),
			" | Isolated" if _stack_is_isolated(battle, stack) else "",
		],
	]
	if bool(stack.get("ranged", false)):
		lines.append("Ranged pressure | Shots %d" % int(stack.get("shots_remaining", 0)))
	else:
		lines.append("Melee pressure | Retaliations %d/%d" % [
			int(stack.get("retaliations_left", 0)),
			int(stack.get("retaliations", 0)),
		])
	if bool(stack.get("defending", false)):
		lines.append("Stance: Defending")
	var effect_summary = SpellRulesScript.effect_summary(stack, battle)
	lines.append("Effects: %s" % (effect_summary if effect_summary != "" else "none"))
	var ability_summary = _stack_ability_summary(stack)
	if ability_summary != "":
		lines.append("Abilities: %s" % ability_summary)
	var objective_summary = _field_objective_focus_line(battle, side, stack)
	if objective_summary != "":
		lines.append(objective_summary)
	return "\n".join(lines)

static func _stack_attack_total(stack: Dictionary, battle: Dictionary) -> int:
	return (
		int(stack.get("attack", 0))
		+ SpellRulesScript.effect_bonus_for_kind(stack, battle, "attack")
		+ _contextual_attack_bonus(stack, battle)
		+ _cohesion_attack_bonus(_stack_cohesion_total(stack, battle))
		+ _momentum_attack_bonus(_stack_momentum_total(stack, battle))
	)

static func _stack_defense_total(stack: Dictionary, battle: Dictionary) -> int:
	return (
		int(stack.get("defense", 0))
		+ SpellRulesScript.effect_bonus_for_kind(stack, battle, "defense")
		+ _contextual_defense_bonus(stack, battle)
		+ _cohesion_defense_bonus(_stack_cohesion_total(stack, battle))
	)

static func _stack_initiative_total(stack: Dictionary, battle: Dictionary) -> int:
	var hero_bonus = _hero_payload_for_side(battle, String(stack.get("side", "")))
	var total = (
		int(stack.get("initiative", 0))
		+ SpellRulesScript.effect_bonus_for_kind(stack, battle, "initiative")
		+ _contextual_initiative_bonus(stack, battle)
		+ _cohesion_initiative_bonus(_stack_cohesion_total(stack, battle))
		+ _momentum_initiative_bonus(_stack_momentum_total(stack, battle))
		+ _field_objective_initiative_bonus(stack, battle)
	)
	return total + int(hero_bonus.get("initiative", 0)) + _faction_initiative_bonus(stack, battle)

static func _stack_cohesion_total(stack: Dictionary, battle: Dictionary) -> int:
	var total = (
		int(stack.get("cohesion", stack.get("cohesion_base", 5)))
		+ SpellRulesScript.effect_bonus_for_kind(stack, battle, "cohesion")
		+ _contextual_cohesion_bonus(stack, battle)
	)
	return clamp(total, COHESION_MIN, COHESION_MAX)

static func _stack_momentum_total(stack: Dictionary, battle: Dictionary) -> int:
	var total = (
		int(stack.get("momentum", 0))
		+ SpellRulesScript.effect_bonus_for_kind(stack, battle, "momentum")
		+ _contextual_momentum_bonus(stack, battle)
	)
	return clamp(total, 0, MOMENTUM_MAX)

static func _cohesion_base_for_unit(unit: Dictionary) -> int:
	var base = 5 + max(0, int(unit.get("tier", 1)) - 1)
	if not bool(unit.get("ranged", false)):
		base += 1
	for ability in unit.get("abilities", []):
		if not (ability is Dictionary):
			continue
		var ability_id = String(ability.get("id", ""))
		if ability_id in ["brace", "formation_guard", "shielding"]:
			base += 1
			break
	if bool(unit.get("ranged", false)) and int(unit.get("hp", 1)) <= 6:
		base -= 1
	return clamp(base, 4, 8)

static func _cohesion_attack_bonus(cohesion: int) -> int:
	if cohesion >= 9:
		return 2
	if cohesion >= 7:
		return 1
	if cohesion <= 2:
		return -2
	if cohesion <= 4:
		return -1
	return 0

static func _cohesion_defense_bonus(cohesion: int) -> int:
	if cohesion >= 8:
		return 1
	if cohesion <= 3:
		return -2
	if cohesion <= 5:
		return -1
	return 0

static func _cohesion_initiative_bonus(cohesion: int) -> int:
	if cohesion >= 8:
		return 1
	if cohesion <= 3:
		return -2
	if cohesion <= 5:
		return -1
	return 0

static func _momentum_attack_bonus(momentum: int) -> int:
	if momentum >= 3:
		return 2
	if momentum >= 1:
		return 1
	return 0

static func _momentum_initiative_bonus(momentum: int) -> int:
	if momentum >= 3:
		return 2
	if momentum >= 1:
		return 1
	return 0

static func _contextual_attack_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var bonus = 0
	var side = String(stack.get("side", ""))
	var round_number = int(battle.get("round", 1))
	if _battle_has_tag(battle, "elevated_fire") and bool(stack.get("ranged", false)):
		bonus += 1
	if _battle_has_tag(battle, "bog_channels") and (_has_ability(stack, "harry") or _has_ability(stack, "backstab") or _has_ability(stack, "bloodrush")):
		bonus += 1
	if _battle_has_tag(battle, "fortress_lane"):
		if _stack_is_anchor_side(stack, battle) and not bool(stack.get("ranged", false)) and (_has_ability(stack, "reach") or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
			bonus += 1
		elif _stack_is_assault_side(stack, battle) and bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
			bonus -= 1
	if _reserve_wave_is_active_for_side(battle, side) and _stack_is_anchor_side(stack, battle) and not _stack_is_isolated(battle, stack):
		bonus += 1
	if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(stack, battle) and bool(stack.get("ranged", false)):
		bonus += 1
		if _stack_has_positive_effect(stack, battle):
			bonus += 1
	if _battle_has_tag(battle, "wall_pressure") and _stack_is_assault_side(stack, battle) and not bool(stack.get("ranged", false)) and round_number >= 3:
		bonus += 1
	if _hero_has_trait(battle, side, "artillerist") and bool(stack.get("ranged", false)) and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
		bonus += 1
	if _hero_has_trait(battle, side, "packhunter") and _enemy_wounded_count(battle, side) > 0:
		bonus += 1
	if _hero_has_trait(battle, side, "vanguard") and not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2:
		bonus += 1
	if _hero_has_trait(battle, side, "ambusher") and not bool(stack.get("ranged", false)) and _battle_has_any_tags(battle, ["ambush_cover"]) and int(battle.get("round", 1)) <= 2:
		bonus += 1
	if _hero_has_trait(battle, side, "bogwise") and (_battle_has_tag(battle, "bog_channels") or String(battle.get("terrain", "")) == "mire") and (_has_ability(stack, "harry") or _has_ability(stack, "backstab") or _has_ability(stack, "bloodrush")):
		bonus += 1
	if String(stack.get("faction_id", "")) == "faction_sunvault" and _stack_has_positive_effect(stack, battle):
		bonus += 1
		if bool(stack.get("ranged", false)) and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
			bonus += 1
	bonus += _field_objective_attack_bonus(stack, battle)
	return bonus

static func _contextual_defense_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var bonus = 0
	var side = String(stack.get("side", ""))
	var round_number = int(battle.get("round", 1))
	if _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not bool(stack.get("ranged", false)) and (_has_ability(stack, "reach") or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _battle_has_tag(battle, "fortress_lane") and _stack_is_anchor_side(stack, battle) and not bool(stack.get("ranged", false)) and (_has_ability(stack, "reach") or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _reserve_wave_is_active_for_side(battle, side) and _stack_is_anchor_side(stack, battle) and not _stack_is_isolated(battle, stack):
		bonus += 1
	if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(stack, battle) and bool(stack.get("ranged", false)) and _stack_has_positive_effect(stack, battle):
		bonus += 1
	if _hero_has_trait(battle, side, "linekeeper") and (bool(stack.get("defending", false)) or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _hero_has_trait(battle, side, "bogwise") and String(battle.get("terrain", "")) == "mire" and not bool(stack.get("ranged", false)):
		bonus += 1
	bonus += _field_objective_defense_bonus(stack, battle)
	return bonus

static func _contextual_cohesion_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var bonus = 0
	var side = String(stack.get("side", ""))
	var round_number = int(battle.get("round", 1))
	if _stack_is_isolated(battle, stack):
		bonus -= 1
	if _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not bool(stack.get("ranged", false)) and (_has_ability(stack, "reach") or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _battle_has_tag(battle, "fortress_lane") and _stack_is_anchor_side(stack, battle) and not bool(stack.get("ranged", false)) and (_has_ability(stack, "reach") or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]) and bool(stack.get("ranged", false)):
		bonus += 1
	if _reserve_wave_is_active_for_side(battle, side) and _stack_is_anchor_side(stack, battle) and not _stack_is_isolated(battle, stack):
		bonus += 1
	if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(stack, battle) and bool(stack.get("ranged", false)):
		bonus += 1
		if _stack_has_positive_effect(stack, battle):
			bonus += 1
	if _battle_has_tag(battle, "wall_pressure") and _stack_is_assault_side(stack, battle) and not bool(stack.get("ranged", false)) and round_number >= 3:
		bonus += 1
	if SpellRulesScript.has_any_effect_ids(stack, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
		bonus -= 1
	var shielding = _ability_by_id(stack, "shielding")
	if not shielding.is_empty():
		bonus += max(0, int(shielding.get("cohesion_hold_bonus", 0)))
	if _hero_has_trait(battle, side, "linekeeper") and (bool(stack.get("defending", false)) or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _hero_has_trait(battle, side, "artillerist") and bool(stack.get("ranged", false)) and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
		bonus += 1
	if _hero_has_trait(battle, side, "bogwise") and (_battle_has_tag(battle, "bog_channels") or String(battle.get("terrain", "")) == "mire") and not _stack_is_isolated(battle, stack):
		bonus += 1
	if _hero_has_trait(battle, side, "ambusher") and not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2 and _battle_has_any_tags(battle, ["ambush_cover"]):
		bonus += 1
	if String(stack.get("faction_id", "")) == "faction_embercourt" and _side_has_role_mix(battle, side) and not _stack_is_isolated(battle, stack):
		bonus += 1
	if String(stack.get("faction_id", "")) == "faction_mireclaw" and _enemy_wounded_count(battle, side) > 0 and not bool(stack.get("ranged", false)):
		bonus += 1
	if String(stack.get("faction_id", "")) == "faction_sunvault" and _stack_has_positive_effect(stack, battle) and not _stack_is_isolated(battle, stack):
		bonus += 1
		if _battle_has_any_tags(battle, ["fortified_line", "elevated_fire"]):
			bonus += 1
	bonus += _field_objective_cohesion_bonus(stack, battle)
	return bonus

static func _contextual_initiative_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var bonus = 0
	var side = String(stack.get("side", ""))
	var round_number = int(battle.get("round", 1))
	if _battle_has_tag(battle, "elevated_fire") and bool(stack.get("ranged", false)):
		bonus += 1
	if _battle_has_tag(battle, "open_lane") and bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2:
		bonus += 1
	if _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) and not bool(stack.get("ranged", false)) and (_has_ability(stack, "reach") or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _battle_has_tag(battle, "fortress_lane") and _stack_is_anchor_side(stack, battle) and not bool(stack.get("ranged", false)) and (_has_ability(stack, "reach") or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")):
		bonus += 1
	if _reserve_wave_is_active_for_side(battle, side) and _stack_is_anchor_side(stack, battle) and not _stack_is_isolated(battle, stack):
		bonus += 1
	if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(stack, battle) and bool(stack.get("ranged", false)):
		bonus += 1
	if _battle_has_tag(battle, "wall_pressure") and _stack_is_assault_side(stack, battle) and not bool(stack.get("ranged", false)) and round_number >= 3:
		bonus += 1
	if _battle_has_tag(battle, "ambush_cover") and not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2:
		bonus += 1
	if _battle_has_tag(battle, "bog_channels") and (_has_ability(stack, "harry") or _has_ability(stack, "backstab") or _has_ability(stack, "bloodrush")):
		bonus += 1
	if _hero_has_trait(battle, side, "linekeeper") and (bool(stack.get("defending", false)) or _battle_has_any_tags(battle, ["chokepoint", "fortified_line"])):
		bonus += 1
	if _hero_has_trait(battle, side, "artillerist") and bool(stack.get("ranged", false)) and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
		bonus += 1
	if _hero_has_trait(battle, side, "ambusher") and not bool(stack.get("ranged", false)) and (String(battle.get("terrain", "")) == "forest" or _battle_has_tag(battle, "ambush_cover")) and int(battle.get("round", 1)) <= 2:
		bonus += 1
	if _hero_has_trait(battle, side, "bogwise") and (_battle_has_tag(battle, "bog_channels") or String(battle.get("terrain", "")) == "mire") and (_has_ability(stack, "harry") or _has_ability(stack, "backstab") or _has_ability(stack, "bloodrush")):
		bonus += 1
	if _hero_has_trait(battle, side, "packhunter") and _enemy_wounded_count(battle, side) > 0 and not bool(stack.get("ranged", false)):
		bonus += 1
	if _hero_has_trait(battle, side, "vanguard") and not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2:
		bonus += 1
	return bonus

static func _contextual_momentum_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var bonus = 0
	var side = String(stack.get("side", ""))
	var round_number = int(battle.get("round", 1))
	if _battle_has_any_tags(battle, ["ambush_cover"]) and not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2:
		bonus += 1
	if _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]) and bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2:
		bonus += 1
	if _battle_has_tag(battle, "bog_channels") and (_has_ability(stack, "harry") or _has_ability(stack, "backstab") or _has_ability(stack, "bloodrush")):
		bonus += 1
	if _reserve_wave_is_active_for_side(battle, side) and _stack_is_anchor_side(stack, battle) and not _stack_is_isolated(battle, stack):
		bonus += 1
	if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(stack, battle) and bool(stack.get("ranged", false)) and (_stack_has_positive_effect(stack, battle) or round_number <= 2):
		bonus += 1
	if _battle_has_tag(battle, "wall_pressure") and _stack_is_assault_side(stack, battle) and not bool(stack.get("ranged", false)) and round_number >= 3:
		bonus += 1
	if _hero_has_trait(battle, side, "packhunter") and _enemy_wounded_count(battle, side) > 0 and not bool(stack.get("ranged", false)):
		bonus += 1
	if _hero_has_trait(battle, side, "vanguard") and not bool(stack.get("ranged", false)) and (int(battle.get("round", 1)) <= 2 or _battle_has_tag(battle, "open_lane")):
		bonus += 1
	if _hero_has_trait(battle, side, "ambusher") and not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2 and (String(battle.get("terrain", "")) == "forest" or _battle_has_tag(battle, "ambush_cover")):
		bonus += 1
	if _hero_has_trait(battle, side, "artillerist") and bool(stack.get("ranged", false)) and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
		bonus += 1
	if _hero_has_trait(battle, side, "bogwise") and (_battle_has_tag(battle, "bog_channels") or String(battle.get("terrain", "")) == "mire") and (_has_ability(stack, "harry") or _has_ability(stack, "backstab") or _has_ability(stack, "bloodrush")):
		bonus += 1
	if String(stack.get("faction_id", "")) == "faction_sunvault" and _stack_has_positive_effect(stack, battle):
		bonus += 1
		if _side_positive_effect_count(battle, side) >= 2 and _battle_has_any_tags(battle, ["elevated_fire", "fortified_line"]):
			bonus += 1
	bonus += _field_objective_momentum_bonus(stack, battle)
	return bonus

static func _faction_initiative_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var faction_id = String(stack.get("faction_id", ""))
	var side = String(stack.get("side", ""))
	match faction_id:
		"faction_embercourt":
			var bonus = 0
			if bool(stack.get("ranged", false)) and _side_defending_count(battle, side) > 0:
				bonus += 1
				if _side_has_ability(battle, side, "formation_guard"):
					bonus += _side_max_ability_int(battle, side, "formation_guard", "ally_ranged_initiative_bonus")
			if int(battle.get("round", 1)) >= 3 and _side_has_role_mix(battle, side):
				bonus += 1
			var formation_guard = _ability_by_id(stack, "formation_guard")
			if not formation_guard.is_empty() and bool(stack.get("defending", false)):
				bonus += int(formation_guard.get("defending_initiative_bonus", 0))
			return bonus
		"faction_mireclaw":
			var bonus = 0
			var wounded_count = _enemy_wounded_count(battle, side)
			if wounded_count > 0:
				bonus += 1
			var bloodrush = _ability_by_id(stack, "bloodrush")
			if not bloodrush.is_empty() and wounded_count > 0:
				bonus += min(
					int(bloodrush.get("max_initiative_bonus", 0)),
					wounded_count * max(1, int(bloodrush.get("wounded_initiative_bonus", 0)))
				)
			if not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) >= 3:
				bonus += 1
			if not bloodrush.is_empty() and int(battle.get("round", 1)) >= 3:
				bonus += int(bloodrush.get("late_round_initiative_bonus", 0))
			return bonus
		"faction_sunvault":
			var bonus = 0
			var positive_effect_count = _side_positive_effect_count(battle, side)
			if _stack_has_positive_effect(stack, battle):
				bonus += 1
				if bool(stack.get("ranged", false)) and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
					bonus += 1
			if positive_effect_count >= 2 and not _stack_is_isolated(battle, stack):
				bonus += 1
			if int(battle.get("round", 1)) >= 3 and positive_effect_count >= 2:
				bonus += 1
			return bonus
		_:
			return 0

static func _apply_round_pressure_shifts(battle: Dictionary) -> void:
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary) or _alive_count(stack) <= 0:
			continue
		var battle_id = String(stack.get("battle_id", ""))
		var side = String(stack.get("side", ""))
		var round_number = int(battle.get("round", 1))
		if _stack_is_isolated(battle, stack):
			_adjust_stack_cohesion(battle, battle_id, -1)
		if SpellRulesScript.has_any_effect_ids(stack, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
			_adjust_stack_cohesion(battle, battle_id, -1)
		if _battle_has_tag(battle, "fortress_lane") and _stack_is_anchor_side(stack, battle) and (bool(stack.get("defending", false)) or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard")) and _stack_cohesion_total(stack, battle) < int(stack.get("cohesion_base", 5)) + 1:
			_adjust_stack_cohesion(battle, battle_id, 1)
		if _reserve_wave_is_active_for_side(battle, side) and _stack_is_anchor_side(stack, battle) and not _stack_is_isolated(battle, stack):
			if _stack_cohesion_total(stack, battle) < int(stack.get("cohesion_base", 5)) + 1:
				_adjust_stack_cohesion(battle, battle_id, 1)
			_adjust_stack_momentum(battle, battle_id, 1)
		if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side(stack, battle) and bool(stack.get("ranged", false)):
			if _stack_cohesion_total(stack, battle) < int(stack.get("cohesion_base", 5)) + 1:
				_adjust_stack_cohesion(battle, battle_id, 1)
			if _stack_has_positive_effect(stack, battle) or round_number <= 2:
				_adjust_stack_momentum(battle, battle_id, 1)
		if _battle_has_tag(battle, "wall_pressure") and round_number >= 3:
			if _stack_is_assault_side(stack, battle) and not bool(stack.get("ranged", false)):
				_adjust_stack_momentum(battle, battle_id, 1)
			elif _stack_is_anchor_side(stack, battle) and bool(stack.get("ranged", false)) and _stack_is_isolated(battle, stack):
				_adjust_stack_cohesion(battle, battle_id, -1)
		if _hero_has_trait(battle, side, "linekeeper") and _stack_cohesion_total(stack, battle) < max(6, int(stack.get("cohesion_base", 5))):
			if bool(stack.get("defending", false)) or _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]) or _has_ability(stack, "brace") or _has_ability(stack, "formation_guard"):
				_adjust_stack_cohesion(battle, battle_id, 1)
		if _hero_has_trait(battle, side, "bogwise") and (_battle_has_tag(battle, "bog_channels") or String(battle.get("terrain", "")) == "mire") and _stack_cohesion_total(stack, battle) < int(stack.get("cohesion_base", 5)) + 1:
			_adjust_stack_cohesion(battle, battle_id, 1)
		if String(stack.get("faction_id", "")) == "faction_embercourt" and int(battle.get("round", 1)) >= 3 and _side_has_role_mix(battle, side) and not _stack_is_isolated(battle, stack) and _stack_cohesion_total(stack, battle) < int(stack.get("cohesion_base", 5)) + 2:
			_adjust_stack_cohesion(battle, battle_id, 1)
		if String(stack.get("faction_id", "")) == "faction_mireclaw" and _enemy_wounded_count(battle, side) > 0 and (_has_ability(stack, "backstab") or _has_ability(stack, "bloodrush") or not bool(stack.get("ranged", false))):
			_adjust_stack_momentum(battle, battle_id, 1)
		if String(stack.get("faction_id", "")) == "faction_sunvault" and _stack_has_positive_effect(stack, battle):
			if not _stack_is_isolated(battle, stack) and _stack_cohesion_total(stack, battle) < int(stack.get("cohesion_base", 5)) + 2:
				_adjust_stack_cohesion(battle, battle_id, 1)
			if _side_positive_effect_count(battle, side) >= 2 and _battle_has_any_tags(battle, ["elevated_fire", "fortified_line"]):
				_adjust_stack_momentum(battle, battle_id, 1)
	_apply_field_objective_round_effects(battle)

static func _adjust_stack_cohesion(battle: Dictionary, battle_id: String, amount: int) -> void:
	if amount == 0:
		return
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			stack["cohesion"] = clamp(int(stack.get("cohesion", stack.get("cohesion_base", 5))) + amount, COHESION_MIN, COHESION_MAX)
			stacks[index] = stack
			break
	battle["stacks"] = stacks

static func _adjust_stack_momentum(battle: Dictionary, battle_id: String, amount: int) -> void:
	if amount == 0:
		return
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			stack["momentum"] = clamp(int(stack.get("momentum", 0)) + amount, 0, MOMENTUM_MAX)
			stacks[index] = stack
			break
	battle["stacks"] = stacks

static func _apply_damage_pressure(
	battle: Dictionary,
	attacker: Dictionary,
	target_before: Dictionary,
	target_after: Dictionary,
	is_ranged: bool,
	source_type: String
) -> Array:
	var messages = []
	if attacker.is_empty() or target_before.is_empty():
		return messages
	var target_battle_id = String(target_before.get("battle_id", ""))
	var attacker_battle_id = String(attacker.get("battle_id", ""))
	var cohesion_shift = _casualty_cohesion_shift(target_before, target_after)
	if not target_after.is_empty() and _alive_count(target_after) > 0 and _stack_is_isolated(battle, target_after):
		cohesion_shift -= 1
	if not target_after.is_empty() and SpellRulesScript.has_any_effect_ids(target_after, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
		cohesion_shift -= 1
	_adjust_stack_cohesion(battle, target_battle_id, cohesion_shift)
	var momentum_gain = _attack_momentum_gain(attacker, target_before, target_after, battle, is_ranged, source_type)
	_adjust_stack_momentum(battle, attacker_battle_id, momentum_gain)
	var support_gain = _supportive_cohesion_gain(attacker, battle, is_ranged)
	_adjust_stack_cohesion(battle, attacker_battle_id, support_gain)
	if target_after.is_empty() or _alive_count(target_after) <= 0:
		_apply_destroyed_stack_shock(battle, target_before, String(attacker.get("side", "")))
	var updated_target = _get_stack_by_id(battle, target_battle_id)
	var updated_attacker = _get_stack_by_id(battle, attacker_battle_id)
	if not updated_target.is_empty() and _alive_count(updated_target) > 0 and _stack_cohesion_total(updated_target, battle) <= 3:
		messages.append("%s is wavering." % _stack_label(updated_target))
	if not updated_attacker.is_empty() and _stack_momentum_total(updated_attacker, battle) >= 3:
		messages.append("%s seizes the tempo." % _stack_label(updated_attacker))
	return messages

static func _casualty_cohesion_shift(target_before: Dictionary, target_after: Dictionary) -> int:
	var before_health = max(1, int(target_before.get("total_health", 0)))
	var after_health = max(0, int(target_after.get("total_health", 0))) if not target_after.is_empty() else 0
	var before_count = _alive_count(target_before)
	var after_count = _alive_count(target_after) if not target_after.is_empty() else 0
	var lost_count = max(0, before_count - after_count)
	var lost_health_ratio = clampf(float(max(0, before_health - after_health)) / float(before_health), 0.0, 1.0)
	if after_count <= 0:
		return -3
	if lost_health_ratio >= 0.45 or lost_count >= 2:
		return -2
	if lost_health_ratio >= 0.18 or lost_count >= 1:
		return -1
	return 0

static func _attack_momentum_gain(
	attacker: Dictionary,
	target_before: Dictionary,
	target_after: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	source_type: String
) -> int:
	var gain = 0
	var side = String(attacker.get("side", ""))
	var destroyed = target_after.is_empty() or _alive_count(target_after) <= 0
	if destroyed:
		gain += 2
	else:
		var before_health = max(1, int(target_before.get("total_health", 0)))
		var after_health = max(0, int(target_after.get("total_health", 0)))
		var lost_ratio = clampf(float(max(0, before_health - after_health)) / float(before_health), 0.0, 1.0)
		if lost_ratio >= 0.25 or _health_ratio(target_after) <= 0.75:
			gain += 1
	if SpellRulesScript.has_any_effect_ids(target_after if not target_after.is_empty() else target_before, battle, [STATUS_HARRIED, STATUS_STAGGERED]):
		gain += 1
	if _stack_cohesion_total(target_before, battle) <= 4:
		gain += 1
	if _hero_has_trait(battle, side, "packhunter") and (_enemy_wounded_count(battle, side) > 0 or SpellRulesScript.has_any_effect_ids(target_after if not target_after.is_empty() else target_before, battle, [STATUS_HARRIED, STATUS_STAGGERED])):
		gain += 1
	if _hero_has_trait(battle, side, "vanguard") and not is_ranged and (int(battle.get("round", 1)) <= 2 or _battle_has_tag(battle, "open_lane")):
		gain += 1
	if _hero_has_trait(battle, side, "artillerist") and is_ranged and _battle_has_any_tags(battle, ["elevated_fire", "open_lane"]):
		gain += 1
	if _hero_has_trait(battle, side, "ambusher") and not is_ranged and int(battle.get("round", 1)) <= 2 and (String(battle.get("terrain", "")) == "forest" or _battle_has_tag(battle, "ambush_cover")):
		gain += 1
	if _hero_has_trait(battle, side, "bogwise") and (_battle_has_tag(battle, "bog_channels") or String(battle.get("terrain", "")) == "mire") and (_has_ability(attacker, "harry") or _has_ability(attacker, "backstab") or _has_ability(attacker, "bloodrush")):
		gain += 1
	var backstab = _ability_by_id(attacker, "backstab")
	if not backstab.is_empty() and SpellRulesScript.has_any_effect_ids(target_after if not target_after.is_empty() else target_before, battle, backstab.get("status_ids", [])):
		gain += max(0, int(backstab.get("momentum_gain", 0)))
	var harry = _ability_by_id(attacker, "harry")
	if not harry.is_empty() and is_ranged:
		gain += max(0, int(harry.get("momentum_gain", 0)))
	var bloodrush = _ability_by_id(attacker, "bloodrush")
	if not bloodrush.is_empty() and (_health_ratio(target_after if not target_after.is_empty() else target_before) <= float(bloodrush.get("wounded_threshold_ratio", 0.0)) or destroyed):
		gain += max(0, int(bloodrush.get("momentum_gain", 0)))
		if destroyed:
			gain += max(0, int(bloodrush.get("kill_momentum_gain", 0)))
	if source_type == "spell":
		gain = max(1, gain)
	return gain

static func _supportive_cohesion_gain(attacker: Dictionary, battle: Dictionary, is_ranged: bool) -> int:
	var gain = 0
	var side = String(attacker.get("side", ""))
	if String(attacker.get("faction_id", "")) == "faction_embercourt" and is_ranged and _side_defending_count(battle, side) > 0:
		gain += 1
	if String(attacker.get("faction_id", "")) == "faction_sunvault" and _stack_has_positive_effect(attacker, battle):
		gain += 1
		if _side_positive_effect_count(battle, side) >= 2 and _battle_has_any_tags(battle, ["fortified_line", "elevated_fire"]):
			gain += 1
	if is_ranged and _side_has_ability(battle, side, "formation_guard"):
		gain += _side_max_ability_int(battle, side, "formation_guard", "ally_cohesion_bonus")
	var formation_guard = _ability_by_id(attacker, "formation_guard")
	if not formation_guard.is_empty() and bool(attacker.get("defending", false)):
		gain += max(0, int(formation_guard.get("defending_cohesion_bonus", 0)))
	return gain

static func _apply_destroyed_stack_shock(battle: Dictionary, destroyed_stack: Dictionary, attacking_side: String) -> void:
	var defending_side = String(destroyed_stack.get("side", ""))
	for ally in _alive_stacks_for_side(battle, defending_side):
		if String(ally.get("battle_id", "")) == String(destroyed_stack.get("battle_id", "")):
			continue
		var shock = -1
		if _hero_has_trait(battle, defending_side, "linekeeper") and _battle_has_any_tags(battle, ["chokepoint", "fortified_line"]):
			shock = 0
		_adjust_stack_cohesion(battle, String(ally.get("battle_id", "")), shock)
	for ally in _alive_stacks_for_side(battle, attacking_side):
		if not bool(ally.get("ranged", false)) or _hero_has_trait(battle, attacking_side, "packhunter"):
			_adjust_stack_momentum(battle, String(ally.get("battle_id", "")), 1)

static func _cohesion_damage_modifier(
	attacker: Dictionary,
	defender: Dictionary,
	battle: Dictionary,
	is_ranged: bool,
	is_retaliation: bool
) -> float:
	var modifier = 1.0
	var attacker_cohesion = _stack_cohesion_total(attacker, battle)
	var defender_cohesion = _stack_cohesion_total(defender, battle)
	var attacker_momentum = _stack_momentum_total(attacker, battle)
	if attacker_cohesion >= 8:
		modifier *= 1.05
	elif attacker_cohesion <= 3:
		modifier *= 0.9
	if defender_cohesion <= 3:
		modifier *= 1.08
	elif defender_cohesion <= 5:
		modifier *= 1.03
	modifier *= 1.0 + (float(attacker_momentum) * 0.04)
	if is_retaliation and attacker_cohesion <= 4:
		modifier *= 0.92
	if is_ranged and _stack_is_isolated(battle, attacker):
		modifier *= 0.94
	return modifier

static func _stack_is_isolated(battle: Dictionary, stack: Dictionary) -> bool:
	if stack.is_empty():
		return false
	var side = String(stack.get("side", ""))
	var living_allies = _alive_stacks_for_side(battle, side)
	if living_allies.size() <= 1:
		return true
	if bool(stack.get("ranged", false)):
		return _allied_melee_count(battle, side) <= 0
	return false

static func _side_defending_count(battle: Dictionary, side: String) -> int:
	var total = 0
	for stack in _alive_stacks_for_side(battle, side):
		if bool(stack.get("defending", false)):
			total += 1
	return total

static func _allied_ranged_count(battle: Dictionary, side: String) -> int:
	var total = 0
	for stack in _alive_stacks_for_side(battle, side):
		if bool(stack.get("ranged", false)):
			total += 1
	return total

static func _allied_melee_count(battle: Dictionary, side: String) -> int:
	var total = 0
	for stack in _alive_stacks_for_side(battle, side):
		if not bool(stack.get("ranged", false)):
			total += 1
	return total

static func _side_has_role_mix(battle: Dictionary, side: String) -> bool:
	var has_ranged = false
	var has_melee = false
	for stack in _alive_stacks_for_side(battle, side):
		if bool(stack.get("ranged", false)):
			has_ranged = true
		else:
			has_melee = true
		if has_ranged and has_melee:
			return true
	return false

static func _enemy_wounded_count(battle: Dictionary, side: String) -> int:
	var target_side = "enemy" if side == "player" else "player"
	var total = 0
	for stack in _alive_stacks_for_side(battle, target_side):
		if _health_ratio(stack) <= 0.75:
			total += 1
	return total

static func _side_doctrine_summary(battle: Dictionary, side: String) -> String:
	var faction_id = _side_faction_id(battle, side)
	match faction_id:
		"faction_embercourt":
			if _battle_has_tag(battle, "fortress_lane") and _stack_is_anchor_side({"side": side}, battle):
				if _reserve_wave_is_active_for_side(battle, side):
					return "Fortress lanes are feeding reserve columns into the pike line"
				return "Fortress lanes are locking the assault into disciplined pike fire"
			if _side_has_ability(battle, side, "formation_guard") and _side_defending_count(battle, side) > 0 and _side_has_role_mix(battle, side):
				return "Pike screens are feeding lantern volleys"
			if _side_has_ability(battle, side, "formation_guard") and _side_defending_count(battle, side) > 0:
				return "Pikewards are locking the firing line"
			if int(battle.get("round", 1)) >= 3 and _side_has_role_mix(battle, side):
				return "Formation fire is tightening the line"
			if _side_defending_count(battle, side) > 0:
				return "Shielded volleys are covering the line"
			return "The line is still forming"
		"faction_mireclaw":
			if _battle_has_tag(battle, "wall_pressure") and _stack_is_assault_side({"side": side}, battle) and int(battle.get("round", 1)) >= 3:
				return "Breach packs are climbing over the line"
			if _reserve_wave_is_active_for_side(battle, side) and _stack_is_anchor_side({"side": side}, battle):
				return "Reserve packs are flooding the breach behind the first wave"
			if _side_has_ability(battle, side, "bloodrush") and _enemy_wounded_count(battle, side) > 0 and int(battle.get("round", 1)) >= 3:
				return "Rippers are driving the collapse"
			if _enemy_wounded_count(battle, side) > 0 and int(battle.get("round", 1)) >= 3:
				return "Blood-rush finishers are cresting"
			if _enemy_wounded_count(battle, side) > 0:
				return "The pack is scenting weakness"
			return "The pack is probing for the first break"
		"faction_sunvault":
			var positive_effect_count = _side_positive_effect_count(battle, side)
			if _battle_has_tag(battle, "battery_nest") and _stack_is_anchor_side({"side": side}, battle):
				if _reserve_wave_is_active_for_side(battle, side):
					return "Battery nests are rotating fresh arrays into the firing line"
				return "Battery nests are turning the approach into a relay kill lane"
			if positive_effect_count >= 3 and _battle_has_any_tags(battle, ["elevated_fire", "fortified_line"]):
				return "Resonant arrays are firing in sequence"
			if positive_effect_count >= 2:
				return "Relay chants are syncing the line"
			if positive_effect_count >= 1:
				return "A resonant array is coming online"
			return "The array is still gathering signal"
		_:
			return "No doctrine is asserting itself"

static func _side_faction_id(battle: Dictionary, side: String) -> String:
	var counts = {}
	for stack in _alive_stacks_for_side(battle, side):
		var faction_id = String(stack.get("faction_id", ""))
		if faction_id == "":
			continue
		counts[faction_id] = int(counts.get(faction_id, 0)) + 1
	var best_id = ""
	var best_count = -1
	for faction_id in counts.keys():
		var count = int(counts[faction_id])
		if count > best_count:
			best_count = count
			best_id = String(faction_id)
	return best_id

static func _hero_command_payload(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var hero = session.overworld.get("hero", {})
	return _hero_payload_from_state(hero, ArtifactRulesScript.aggregate_bonuses(hero), session, "player")

static func _hero_payload_from_state(
	hero_state: Dictionary,
	bonuses: Dictionary = {},
	session: SessionStateStoreScript.SessionData = null,
	side: String = "player"
) -> Dictionary:
	var command = hero_state.get("command", {})
	var resolved_bonuses = bonuses.duplicate(true) if bonuses is Dictionary else {}
	var specialty_bonuses = HeroProgressionRulesScript.aggregate_bonuses(hero_state)
	var battle_traits = _normalized_battle_traits(hero_state)
	resolved_bonuses["battle_attack"] = int(resolved_bonuses.get("battle_attack", 0)) + int(specialty_bonuses.get("battle_attack", 0))
	resolved_bonuses["battle_defense"] = int(resolved_bonuses.get("battle_defense", 0)) + int(specialty_bonuses.get("battle_defense", 0))
	resolved_bonuses["battle_initiative"] = int(resolved_bonuses.get("battle_initiative", 0)) + int(specialty_bonuses.get("battle_initiative", 0))
	var mana = hero_state.get("spellbook", {}).get("mana", {})
	return {
		"attack": int(command.get("attack", 0)) + int(resolved_bonuses.get("battle_attack", 0)),
		"defense": int(command.get("defense", 0)) + int(resolved_bonuses.get("battle_defense", 0)),
		"initiative": int(resolved_bonuses.get("battle_initiative", 0)) + DifficultyRulesScript.initiative_bonus_for_side(session, side),
		"damage_multiplier": DifficultyRulesScript.damage_multiplier_for_side(session, side),
		"mana_current": int(mana.get("current", 0)),
		"mana_max": int(mana.get("max", 0)),
		"battle_traits": battle_traits,
	}

static func _hero_payload_for_side(battle: Dictionary, side: String) -> Dictionary:
	if side == "player":
		return battle.get("player_hero", {})
	return battle.get("enemy_hero_payload", {})

static func _enemy_commander_state(encounter: Dictionary) -> Dictionary:
	var commander = encounter.get("enemy_commander", {})
	if not (commander is Dictionary) or commander.is_empty():
		return {}
	var command = _normalize_command(commander.get("command", {}))
	return SpellRulesScript.ensure_hero_spellbook(
		{
			"name": String(commander.get("name", "Enemy Commander")),
			"command": command,
			"battle_traits": _normalized_battle_traits(commander),
		},
		{
			"command": command,
			"starting_spell_ids": commander.get("starting_spell_ids", []),
		}
	)

static func _normalize_enemy_hero_state(existing_state: Variant, encounter: Dictionary) -> Dictionary:
	var template = _enemy_commander_state(encounter)
	if not (existing_state is Dictionary) or existing_state.is_empty():
		return template
	var normalized = existing_state.duplicate(true)
	normalized["name"] = String(normalized.get("name", template.get("name", "Enemy Commander")))
	normalized["command"] = _normalize_command(normalized.get("command", template.get("command", {})))
	normalized["battle_traits"] = _normalized_battle_traits(normalized if normalized.has("battle_traits") else template)
	return SpellRulesScript.ensure_hero_spellbook(
		normalized,
		{
			"command": template.get("command", {}),
			"starting_spell_ids": template.get("spellbook", {}).get("known_spell_ids", []),
		}
	)

static func _normalized_battle_traits(value: Variant) -> Array:
	var source = []
	if value is Dictionary:
		source = value.get("battle_traits", [])
	elif value is Array:
		source = value
	var normalized = []
	if not (source is Array):
		source = []
	for trait_value in source:
		var trait_id = String(trait_value)
		if trait_id != "" and trait_id not in normalized:
			normalized.append(trait_id)
	if normalized.is_empty() and value is Dictionary:
		var hero_id = String(value.get("id", ""))
		if hero_id != "":
			for trait_value in ContentService.get_hero(hero_id).get("battle_traits", []):
				var trait_id = String(trait_value)
				if trait_id != "" and trait_id not in normalized:
					normalized.append(trait_id)
	return normalized

static func _normalized_battlefield_tags(encounter: Dictionary, context: Variant = {}) -> Array:
	var normalized = []
	for tag_value in encounter.get("battlefield_tags", []):
		var tag_id = String(tag_value)
		if tag_id != "" and tag_id not in normalized:
			normalized.append(tag_id)
	if _is_town_defense_context(context) or _is_town_assault_context(context):
		for tag_id in ["fortified_line", "chokepoint"]:
			if tag_id not in normalized:
				normalized.append(tag_id)
		for tag_value in context.get("battlefront_tags", []):
			var context_tag = String(tag_value)
			if context_tag != "" and context_tag not in normalized:
				normalized.append(context_tag)
	return normalized

static func _normalize_command(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {"attack": 0, "defense": 0, "power": 0, "knowledge": 0}
	return {
		"attack": max(0, int(value.get("attack", 0))),
		"defense": max(0, int(value.get("defense", 0))),
		"power": max(0, int(value.get("power", 0))),
		"knowledge": max(0, int(value.get("knowledge", 0))),
	}

static func _starting_distance_for_encounter(encounter: Dictionary, context: Variant = {}) -> int:
	var distance = _starting_distance_for_terrain(String(encounter.get("terrain", "plains")))
	var battlefield_tags = _normalized_battlefield_tags(encounter, context)
	if "chokepoint" in battlefield_tags or "fortified_line" in battlefield_tags or "fortress_lane" in battlefield_tags or "wall_pressure" in battlefield_tags:
		distance = min(distance, 1)
	if "elevated_fire" in battlefield_tags or "open_lane" in battlefield_tags or "battery_nest" in battlefield_tags:
		distance = max(distance, 2)
	return clamp(distance, 0, 2)

static func _starting_distance_for_terrain(terrain: String) -> int:
	match terrain:
		"forest":
			return 2
		"mire":
			return 1
		_:
			return 1

static func _normalize_side_token(side: String, allow_neutral: bool = true) -> String:
	match side:
		"player", "enemy":
			return side
		"neutral":
			return "neutral" if allow_neutral else ""
		_:
			return "neutral" if allow_neutral else ""

static func _opposing_side(side: String) -> String:
	if side == "player":
		return "enemy"
	if side == "enemy":
		return "player"
	return ""

static func _normalize_field_objectives(
	existing_value: Variant,
	encounter: Dictionary,
	encounter_placement: Dictionary,
	scenario: Dictionary,
	context: Variant = {}
) -> Array:
	var existing_by_id = {}
	if existing_value is Array:
		for entry in existing_value:
			if entry is Dictionary:
				var existing_id = String(entry.get("id", ""))
				if existing_id != "":
					existing_by_id[existing_id] = entry
	var normalized = []
	for entry in _authored_field_objectives(encounter, encounter_placement, scenario, context):
		if not (entry is Dictionary):
			continue
		var objective_id = String(entry.get("id", ""))
		if objective_id == "":
			continue
		normalized.append(_normalize_field_objective(entry, existing_by_id.get(objective_id, {}), context))
	return normalized

static func _authored_field_objectives(
	encounter: Dictionary,
	encounter_placement: Dictionary,
	scenario: Dictionary,
	context: Variant = {}
) -> Array:
	var ordered_ids = []
	var merged = {}
	for source in [encounter.get(FIELD_OBJECTIVES_KEY, []), encounter_placement.get(FIELD_OBJECTIVES_KEY, [])]:
		if not (source is Array):
			continue
		for entry in source:
			if not (entry is Dictionary):
				continue
			var objective_id = String(entry.get("id", ""))
			if objective_id == "":
				continue
			if not merged.has(objective_id):
				ordered_ids.append(objective_id)
				merged[objective_id] = entry.duplicate(true)
			else:
				var current = merged[objective_id]
				if current is Dictionary:
					for key in entry.keys():
						current[String(key)] = entry[key]
					merged[objective_id] = current
	var authored = []
	for objective_id in ordered_ids:
		authored.append(merged.get(objective_id, {}))
	return authored

static func _normalize_field_objective(entry: Dictionary, existing_state: Variant, context: Variant = {}) -> Dictionary:
	var objective_type = String(entry.get("type", ""))
	var starting_side = _normalize_side_token(String(entry.get("starting_side", "neutral")))
	var capture_threshold = max(1, int(entry.get("capture_threshold", 2)))
	var urgency_round = max(1, int(entry.get("urgency_round", 2)))
	var state = existing_state if existing_state is Dictionary else {}
	var control_side = _normalize_side_token(String(state.get("control_side", starting_side)))
	if control_side == "":
		control_side = starting_side
	var progress_side = _normalize_side_token(String(state.get("progress_side", "")))
	if progress_side == control_side:
		progress_side = ""
	var progress_value = clamp(int(state.get("progress_value", 0)), 0, capture_threshold)
	return {
		"id": String(entry.get("id", "")),
		"type": objective_type,
		"label": String(entry.get("label", _titleize_token(String(entry.get("id", objective_type))))),
		"summary": String(entry.get("summary", _default_field_objective_summary(objective_type))),
		"starting_side": starting_side,
		"control_side": control_side,
		"progress_side": progress_side,
		"progress_value": progress_value if progress_side != "" else 0,
		"capture_threshold": capture_threshold,
		"urgency_round": urgency_round,
		"pressure_tags": _normalize_string_array(entry.get("pressure_tags", _default_field_objective_pressure_tags(objective_type))),
		"last_flip_round": max(0, int(state.get("last_flip_round", 0))),
	}

static func _default_field_objective_summary(objective_type: String) -> String:
	match objective_type:
		"lane_battery":
			return "Lane batteries sharpen ranged pressure until the approach is broken."
		"cover_line":
			return "A cover line screens the firing lane and keeps exposed command safer."
		"obstruction_line":
			return "An obstruction line clogs the approach until the barrier is forced aside."
		"ritual_pylon":
			return "A ritual pylon steals tempo and batters cohesion from the loose line."
		"supply_post":
			return "A supply post stabilizes the line and pulls reserve companies forward sooner."
		"signal_beacon":
			return "A signal beacon guides the line and keeps command safer under pressure."
		"breach_point":
			return "A breach point decides whether the late melee collapses or holds."
		"hazard_zone":
			return "A hazard zone punishes the side that fails to seize the safer lane."
		_:
			return "Battlefield pressure still hangs on this point."

static func _default_field_objective_pressure_tags(objective_type: String) -> Array:
	match objective_type:
		"lane_battery":
			return ["ranged", "initiative"]
		"cover_line":
			return ["ranged", "commander", "cohesion"]
		"obstruction_line":
			return ["cohesion", "momentum", "urgency"]
		"ritual_pylon":
			return ["initiative", "cohesion"]
		"supply_post":
			return ["cohesion", "reinforcement"]
		"signal_beacon":
			return ["initiative", "commander"]
		"breach_point":
			return ["momentum", "cohesion"]
		"hazard_zone":
			return ["cohesion", "urgency"]
		_:
			return []

static func _field_objectives(battle: Dictionary) -> Array:
	var objectives = battle.get(FIELD_OBJECTIVES_KEY, [])
	return objectives if objectives is Array else []

static func _field_objective_label(objective: Dictionary) -> String:
	return String(objective.get("label", objective.get("id", "Objective")))

static func _field_objective_progress_text(objective: Dictionary) -> String:
	var controller = String(objective.get("control_side", "neutral"))
	var progress_side = String(objective.get("progress_side", ""))
	var progress_value = int(objective.get("progress_value", 0))
	var threshold = max(1, int(objective.get("capture_threshold", 2)))
	if controller in ["player", "enemy"]:
		if progress_side != "" and progress_side != controller and progress_value > 0:
			return "%s-held, %s pressure %d/%d" % [
				_side_label(controller),
				_side_label(progress_side),
				progress_value,
				threshold,
			]
		return "%s-held" % _side_label(controller)
	if progress_side != "" and progress_value > 0:
		return "contested toward %s %d/%d" % [_side_label(progress_side), progress_value, threshold]
	return "unclaimed"

static func _field_objective_short_status(objective: Dictionary) -> String:
	return "%s %s" % [_field_objective_label(objective), _field_objective_progress_text(objective)]

static func _field_objective_status_brief(battle: Dictionary) -> String:
	var objectives = _field_objectives(battle)
	if objectives.is_empty():
		return ""
	var primary = objectives[0]
	if primary is Dictionary:
		return _field_objective_short_status(primary)
	return ""

static func _field_objective_pressure_summary(battle: Dictionary) -> String:
	var parts = []
	for objective in _field_objectives(battle):
		if not (objective is Dictionary):
			continue
		parts.append("%s | %s" % [_field_objective_short_status(objective), String(objective.get("summary", ""))])
		if parts.size() >= 2:
			break
	return " ; ".join(parts)

static func _field_objective_pressure_brief(battle: Dictionary) -> String:
	for objective in _field_objectives(battle):
		if not (objective is Dictionary):
			continue
		var objective_type = String(objective.get("type", ""))
		var controller = String(objective.get("control_side", "neutral"))
		var urgency_round = int(objective.get("urgency_round", 2))
		match objective_type:
			"lane_battery":
				if controller == "enemy" and int(battle.get("distance", 1)) > 0:
					return "%s still controls the firing lane." % _field_objective_label(objective)
				if controller == "player" and int(battle.get("distance", 1)) > 0:
					return "%s now favors the friendly guns." % _field_objective_label(objective)
			"cover_line":
				if controller == "enemy" and int(battle.get("distance", 1)) > 0:
					return "%s is still screening the enemy guns and commander." % _field_objective_label(objective)
				if controller == "player" and int(battle.get("distance", 1)) > 0:
					return "%s now shelters the friendly firing line." % _field_objective_label(objective)
			"obstruction_line":
				if controller == "enemy" and int(battle.get("distance", 1)) > 0:
					return "%s is still compressing the approach." % _field_objective_label(objective)
				if controller == "player" and int(battle.get("distance", 1)) > 0:
					return "%s has turned the choke back on the enemy push." % _field_objective_label(objective)
			"ritual_pylon":
				if controller == "enemy" and int(battle.get("round", 1)) >= urgency_round:
					return "%s is grinding the line's cohesion." % _field_objective_label(objective)
				if controller == "player" and int(battle.get("round", 1)) >= urgency_round:
					return "%s now breaks the enemy rhythm." % _field_objective_label(objective)
			"supply_post":
				if controller == "enemy" and _battle_has_tag(battle, "reserve_wave"):
					return "%s is feeding enemy reserves to the front." % _field_objective_label(objective)
				if controller == "player" and _battle_has_tag(battle, "reserve_wave"):
					return "%s is delaying enemy reserve timing." % _field_objective_label(objective)
			"signal_beacon":
				if controller == "enemy":
					return "%s is keeping enemy command ahead of the exchange." % _field_objective_label(objective)
				if controller == "player":
					return "%s is stabilizing friendly command tempo." % _field_objective_label(objective)
			"breach_point":
				if controller in ["player", "enemy"] and int(battle.get("round", 1)) >= urgency_round:
					return "%s is deciding the melee collapse." % _field_objective_label(objective)
			"hazard_zone":
				if controller == "enemy" and int(battle.get("round", 1)) >= urgency_round:
					return "%s is still punishing the approach." % _field_objective_label(objective)
				if controller == "player" and int(battle.get("round", 1)) >= urgency_round:
					return "%s has been turned back on the enemy line." % _field_objective_label(objective)
	return ""

static func _field_objective_urgency_summary(session: SessionStateStoreScript.SessionData, battle: Dictionary) -> String:
	var parts = []
	var urgent = []
	for objective in _field_objectives(battle):
		if objective is Dictionary and int(battle.get("round", 1)) >= int(objective.get("urgency_round", 2)):
			urgent.append(_field_objective_short_status(objective))
	if urgent.is_empty():
		var objective_brief = _field_objective_status_brief(battle)
		if objective_brief != "":
			parts.append(objective_brief)
	else:
		parts.append("Active pressure %s" % "; ".join(urgent.slice(0, min(2, urgent.size()))))
	var scenario_line = _tactical_objective_line(session, battle, ContentService.get_scenario(session.scenario_id)).trim_prefix("Battle aim: ").strip_edges()
	if scenario_line != "":
		parts.append(scenario_line)
	var rounds_remaining = max(0, int(battle.get("max_rounds", 12)) - int(battle.get("round", 1)) + 1)
	if rounds_remaining <= 2:
		parts.append("%d round%s remain before stalemate" % [rounds_remaining, "" if rounds_remaining == 1 else "s"])
	if not bool(battle.get("retreat_allowed", true)):
		parts.append("retreat locked")
	return " | ".join(parts)

static func _field_objective_focus_line(battle: Dictionary, side: String, stack: Dictionary = {}) -> String:
	if side == "":
		return ""
	var preferred_ranged = stack is Dictionary and bool(stack.get("ranged", false))
	for objective in _field_objectives(battle):
		if not (objective is Dictionary):
			continue
		var controller = String(objective.get("control_side", "neutral"))
		var objective_type = String(objective.get("type", ""))
		if controller == side:
			match objective_type:
				"lane_battery":
					if preferred_ranged:
						return "Objective: %s supports this firing line." % _field_objective_label(objective)
				"cover_line":
					return "Objective: %s is screening this side from hostile fire." % _field_objective_label(objective)
				"obstruction_line":
					return "Objective: %s is choking the lane in this side's favor." % _field_objective_label(objective)
				"supply_post":
					return "Objective: %s is keeping this side steadier." % _field_objective_label(objective)
				"signal_beacon":
					return "Objective: %s is guiding command tempo here." % _field_objective_label(objective)
				"breach_point":
					return "Objective: %s currently favors this side's melee." % _field_objective_label(objective)
				"ritual_pylon", "hazard_zone":
					return "Objective: %s currently pressures the enemy line." % _field_objective_label(objective)
		elif controller in ["player", "enemy"]:
			match objective_type:
				"lane_battery":
					if preferred_ranged or int(battle.get("distance", 1)) > 0:
						return "Objective: %s is still working against this side." % _field_objective_label(objective)
				"cover_line":
					return "Objective: %s is still screening the hostile line." % _field_objective_label(objective)
				"obstruction_line":
					return "Objective: %s is still clogging this push." % _field_objective_label(objective)
				"ritual_pylon", "hazard_zone":
					return "Objective: %s is dragging this side under pressure." % _field_objective_label(objective)
				"supply_post", "signal_beacon", "breach_point":
					return "Objective: %s is still in hostile hands." % _field_objective_label(objective)
	return ""

static func _side_controls_field_objective_type(battle: Dictionary, side: String, objective_type: String) -> bool:
	for objective in _field_objectives(battle):
		if objective is Dictionary and String(objective.get("type", "")) == objective_type and String(objective.get("control_side", "")) == side:
			return true
	return false

static func _reserve_wave_ready_round(battle: Dictionary, side: String) -> int:
	var ready_round = 3
	if side == "":
		return ready_round
	if _side_controls_field_objective_type(battle, side, "supply_post"):
		ready_round -= 1
	elif _side_controls_field_objective_type(battle, _opposing_side(side), "supply_post"):
		ready_round += 1
	return clamp(ready_round, 2, 4)

static func _reserve_wave_is_active_for_side(battle: Dictionary, side: String) -> bool:
	return side != "" and _battle_has_tag(battle, "reserve_wave") and int(battle.get("round", 1)) >= _reserve_wave_ready_round(battle, side)

static func _field_objective_initiative_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var side = String(stack.get("side", ""))
	var bonus = 0
	for objective in _field_objectives(battle):
		if not (objective is Dictionary) or String(objective.get("control_side", "")) != side:
			continue
		match String(objective.get("type", "")):
			"signal_beacon":
				bonus += 1
			"lane_battery":
				if bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
					bonus += 1
			"cover_line":
				if bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
					bonus += 1
			"obstruction_line":
				if not bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0 and (
					_has_ability(stack, "reach")
					or _has_ability(stack, "brace")
					or _has_ability(stack, "formation_guard")
				):
					bonus += 1
			"ritual_pylon":
				if int(battle.get("round", 1)) >= int(objective.get("urgency_round", 2)):
					bonus += 1
			"supply_post":
				if _reserve_wave_is_active_for_side(battle, side):
					bonus += 1
	return min(bonus, 2)

static func _field_objective_attack_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var side = String(stack.get("side", ""))
	var bonus = 0
	for objective in _field_objectives(battle):
		if not (objective is Dictionary) or String(objective.get("control_side", "")) != side:
			continue
		match String(objective.get("type", "")):
			"lane_battery":
				if bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
					bonus += 1
			"cover_line":
				if bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0 and not _stack_is_isolated(battle, stack):
					bonus += 1
			"obstruction_line":
				if not bool(stack.get("ranged", false)) and (
					int(battle.get("distance", 1)) <= 1
					or int(battle.get("round", 1)) >= int(objective.get("urgency_round", 2))
				):
					bonus += 1
			"breach_point":
				if not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) >= int(objective.get("urgency_round", 3)):
					bonus += 1
	return min(bonus, 2)

static func _field_objective_defense_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var side = String(stack.get("side", ""))
	var bonus = 0
	for objective in _field_objectives(battle):
		if not (objective is Dictionary) or String(objective.get("control_side", "")) != side:
			continue
		match String(objective.get("type", "")):
			"cover_line":
				if bool(stack.get("ranged", false)) or bool(stack.get("defending", false)):
					bonus += 1
			"obstruction_line":
				if not bool(stack.get("ranged", false)):
					bonus += 1
			"supply_post":
				if not _stack_is_isolated(battle, stack):
					bonus += 1
			"signal_beacon":
				bonus += 1
			"breach_point":
				if _stack_is_anchor_side(stack, battle):
					bonus += 1
	return min(bonus, 2)

static func _field_objective_cohesion_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var side = String(stack.get("side", ""))
	var bonus = 0
	for objective in _field_objectives(battle):
		if not (objective is Dictionary):
			continue
		var controller = String(objective.get("control_side", "neutral"))
		match String(objective.get("type", "")):
			"cover_line":
				if controller == side and (bool(stack.get("ranged", false)) or not _stack_is_isolated(battle, stack)):
					bonus += 1
				elif controller == _opposing_side(side) and bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
					bonus -= 1
			"obstruction_line":
				if controller == side and not bool(stack.get("ranged", false)):
					bonus += 1
				elif controller == _opposing_side(side) and not bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0:
					bonus -= 1
			"supply_post":
				if controller == side and not _stack_is_isolated(battle, stack):
					bonus += 1
			"breach_point":
				if controller == side and _stack_is_anchor_side(stack, battle):
					bonus += 1
			"hazard_zone", "ritual_pylon":
				if controller == _opposing_side(side) and int(battle.get("round", 1)) >= int(objective.get("urgency_round", 2)):
					bonus -= 1
	return clamp(bonus, -2, 2)

static func _field_objective_momentum_bonus(stack: Dictionary, battle: Dictionary) -> int:
	var side = String(stack.get("side", ""))
	var bonus = 0
	for objective in _field_objectives(battle):
		if not (objective is Dictionary) or String(objective.get("control_side", "")) != side:
			continue
		match String(objective.get("type", "")):
			"cover_line":
				if bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2 and int(battle.get("distance", 1)) > 0:
					bonus += 1
			"obstruction_line":
				if not bool(stack.get("ranged", false)) and int(battle.get("distance", 1)) > 0 and int(battle.get("round", 1)) >= int(objective.get("urgency_round", 2)):
					bonus += 1
			"breach_point":
				if not bool(stack.get("ranged", false)) and int(battle.get("round", 1)) >= int(objective.get("urgency_round", 3)):
					bonus += 1
			"lane_battery":
				if bool(stack.get("ranged", false)) and int(battle.get("round", 1)) <= 2 and int(battle.get("distance", 1)) > 0:
					bonus += 1
	return min(bonus, 2)

static func _field_objective_commander_modifier(attacker: Dictionary, defender: Dictionary, battle: Dictionary) -> float:
	var modifier = 1.0
	var attacker_side = String(attacker.get("side", ""))
	var defender_side = String(defender.get("side", ""))
	if _side_controls_field_objective_type(battle, attacker_side, "cover_line") and int(battle.get("distance", 1)) > 0:
		modifier *= 1.03
	if _side_controls_field_objective_type(battle, defender_side, "cover_line") and int(battle.get("distance", 1)) > 0:
		modifier *= 0.97
	if _side_controls_field_objective_type(battle, attacker_side, "signal_beacon"):
		modifier *= 1.04
	if _side_controls_field_objective_type(battle, defender_side, "signal_beacon"):
		modifier *= 0.96
	if (
		not bool(attacker.get("ranged", false))
		and _side_controls_field_objective_type(battle, defender_side, "obstruction_line")
		and int(battle.get("distance", 1)) > 0
	):
		modifier *= 0.97
	if (
		not bool(attacker.get("ranged", false))
		and _side_controls_field_objective_type(battle, attacker_side, "obstruction_line")
		and int(battle.get("round", 1)) >= 2
	):
		modifier *= 1.02
	if _side_controls_field_objective_type(battle, attacker_side, "ritual_pylon"):
		modifier *= 1.03
	return modifier

static func _apply_field_objective_action_pressure(battle: Dictionary, action_context: Dictionary) -> Array:
	var acting_side = String(action_context.get("side", ""))
	if acting_side not in ["player", "enemy"]:
		return []
	var acting_stack = _get_stack_by_id(battle, String(action_context.get("battle_id", "")))
	var target_stack = _get_stack_by_id(battle, String(action_context.get("target_battle_id", "")))
	var messages = []
	var objectives = _field_objectives(battle)
	for index in range(objectives.size()):
		var objective = objectives[index]
		if not (objective is Dictionary):
			continue
		var influence = _field_objective_action_influence(objective, battle, acting_side, action_context, acting_stack, target_stack)
		if influence <= 0:
			continue
		var event_text = _apply_field_objective_control_push(objective, battle, acting_side, influence)
		objectives[index] = objective
		if event_text != "":
			messages.append(event_text)
	battle[FIELD_OBJECTIVES_KEY] = objectives
	return messages

static func _field_objective_action_influence(
	objective: Dictionary,
	battle: Dictionary,
	acting_side: String,
	action_context: Dictionary,
	acting_stack: Dictionary,
	target_stack: Dictionary
) -> int:
	var action = String(action_context.get("action", ""))
	var controller = String(objective.get("control_side", "neutral"))
	var contested = controller != acting_side
	var is_ranged = bool(acting_stack.get("ranged", false))
	match String(objective.get("type", "")):
		"lane_battery":
			match action:
				"advance":
					return 2 if contested and not is_ranged else (1 if contested else 0)
				"strike":
					return 2 if contested and not is_ranged else 1
				"shoot":
					if is_ranged:
						if acting_side == controller:
							return 2
						return 2 if bool(target_stack.get("ranged", false)) else 1
				"defend":
					return 1 if acting_side == controller and (is_ranged or _has_ability(acting_stack, "brace") or _has_ability(acting_stack, "formation_guard")) else 0
		"cover_line":
			match action:
				"advance":
					return 2 if contested and not is_ranged else (1 if contested else 0)
				"strike":
					return 2 if contested and not is_ranged else 1
				"shoot":
					return 1 if is_ranged and acting_side == controller else 0
				"defend":
					return 2 if acting_side == controller and (
						is_ranged
						or _has_ability(acting_stack, "brace")
						or _has_ability(acting_stack, "formation_guard")
					) else (1 if contested and not is_ranged else 0)
				"cast_spell":
					return 1
		"obstruction_line":
			match action:
				"advance":
					return 2 if contested and not is_ranged else (1 if contested else 0)
				"strike":
					return 2 if not is_ranged else 0
				"defend":
					return 2 if acting_side == controller and (
						not is_ranged
						or _has_ability(acting_stack, "brace")
						or _has_ability(acting_stack, "formation_guard")
						or _has_ability(acting_stack, "reach")
					) else (1 if contested and not is_ranged else 0)
		"ritual_pylon":
			match action:
				"advance", "strike":
					return 2 if contested and not is_ranged else 1
				"cast_spell":
					return 1
				"defend":
					return 1 if acting_side == controller else 0
		"supply_post":
			match action:
				"defend":
					return 2
				"strike":
					return 1 if not is_ranged else 0
				"advance":
					return 1 if contested and not is_ranged else 0
		"signal_beacon":
			match action:
				"advance":
					return 1 if contested else 0
				"defend":
					return 2 if acting_side == controller else 1
				"shoot":
					return 1 if is_ranged else 0
				"cast_spell":
					return 1
		"breach_point":
			match action:
				"advance":
					return 2 if not is_ranged else 0
				"strike":
					return 2 if not is_ranged else 1
				"defend":
					return 2 if acting_side == controller and _stack_is_anchor_side({"side": acting_side}, battle) else 0
		"hazard_zone":
			match action:
				"advance", "strike":
					return 2 if contested and not is_ranged else 1
				"cast_spell":
					return 1
				"defend":
					return 1 if acting_side == controller else 0
	return 0

static func _apply_field_objective_control_push(objective: Dictionary, battle: Dictionary, acting_side: String, amount: int) -> String:
	if amount <= 0:
		return ""
	var controller = String(objective.get("control_side", "neutral"))
	var progress_side = String(objective.get("progress_side", ""))
	var progress_value = max(0, int(objective.get("progress_value", 0)))
	var threshold = max(1, int(objective.get("capture_threshold", 2)))
	if controller == acting_side:
		if progress_side != "" and progress_side != acting_side:
			progress_value = max(0, progress_value - amount)
			if progress_value <= 0:
				progress_side = ""
		else:
			progress_side = ""
			progress_value = 0
	else:
		if progress_side != "" and progress_side != acting_side:
			progress_value = max(0, progress_value - amount)
			if progress_value <= 0:
				progress_side = acting_side
				progress_value = amount
		else:
			progress_side = acting_side
			progress_value += amount
		if progress_value >= threshold:
			var previous_controller = controller
			controller = acting_side
			progress_side = ""
			progress_value = 0
			objective["control_side"] = controller
			objective["progress_side"] = progress_side
			objective["progress_value"] = progress_value
			objective["last_flip_round"] = int(battle.get("round", 1))
			return _field_objective_flip_message(objective, previous_controller, controller)
	objective["control_side"] = controller
	objective["progress_side"] = progress_side
	objective["progress_value"] = progress_value if progress_side != "" else 0
	return ""

static func _field_objective_flip_message(objective: Dictionary, previous_controller: String, new_controller: String) -> String:
	var label = _field_objective_label(objective)
	if previous_controller in ["player", "enemy"]:
		return "%s swings to %s control." % [label, _side_label(new_controller)]
	return "%s is seized by %s." % [label, _side_label(new_controller)]

static func _apply_field_objective_round_effects(battle: Dictionary) -> void:
	for objective in _field_objectives(battle):
		if not (objective is Dictionary):
			continue
		var controller = String(objective.get("control_side", "neutral"))
		if controller not in ["player", "enemy"]:
			continue
		match String(objective.get("type", "")):
			"cover_line":
				var screened = _weakest_stack_by_role(battle, controller, true)
				if screened.is_empty():
					screened = _weakest_stack_by_cohesion(battle, controller)
				if not screened.is_empty() and _stack_cohesion_total(screened, battle) < int(screened.get("cohesion_base", 5)) + 1:
					_adjust_stack_cohesion(battle, String(screened.get("battle_id", "")), 1)
			"obstruction_line":
				var blocking_line = _weakest_stack_by_role(battle, controller, false)
				if not blocking_line.is_empty() and _stack_cohesion_total(blocking_line, battle) < int(blocking_line.get("cohesion_base", 5)) + 1:
					_adjust_stack_cohesion(battle, String(blocking_line.get("battle_id", "")), 1)
				if int(battle.get("distance", 1)) > 0:
					var stalled = _highest_momentum_stack_for_side(battle, _opposing_side(controller))
					if not stalled.is_empty() and not bool(stalled.get("ranged", false)):
						_adjust_stack_momentum(battle, String(stalled.get("battle_id", "")), -1)
			"ritual_pylon":
				if int(battle.get("round", 1)) >= int(objective.get("urgency_round", 2)):
					var pressured = _weakest_stack_by_cohesion(battle, _opposing_side(controller))
					if not pressured.is_empty():
						_adjust_stack_cohesion(battle, String(pressured.get("battle_id", "")), -1)
			"supply_post":
				var steadied = _weakest_stack_by_cohesion(battle, controller)
				if not steadied.is_empty() and _stack_cohesion_total(steadied, battle) < int(steadied.get("cohesion_base", 5)) + 1:
					_adjust_stack_cohesion(battle, String(steadied.get("battle_id", "")), 1)
			"breach_point":
				if int(battle.get("round", 1)) >= int(objective.get("urgency_round", 3)):
					var surge_stack = _highest_momentum_stack_for_side(battle, controller)
					if not surge_stack.is_empty() and not bool(surge_stack.get("ranged", false)):
						_adjust_stack_momentum(battle, String(surge_stack.get("battle_id", "")), 1)
					var pressured_line = _weakest_stack_by_cohesion(battle, _opposing_side(controller))
					if not pressured_line.is_empty():
						_adjust_stack_cohesion(battle, String(pressured_line.get("battle_id", "")), -1)
			"hazard_zone":
				if int(battle.get("round", 1)) >= int(objective.get("urgency_round", 2)):
					var exposed = _weakest_stack_by_cohesion(battle, _opposing_side(controller))
					if not exposed.is_empty():
						_adjust_stack_cohesion(battle, String(exposed.get("battle_id", "")), -1)

static func _highest_momentum_stack_for_side(battle: Dictionary, side: String) -> Dictionary:
	var best = {}
	var best_score = -99999
	for stack in _alive_stacks_for_side(battle, side):
		var score = _stack_momentum_total(stack, battle) * 3
		score += _stack_attack_total(stack, battle)
		if bool(stack.get("ranged", false)):
			score -= 2
		if best.is_empty() or score > best_score:
			best = stack
			best_score = score
	return best

static func _battle_seed(session: SessionStateStoreScript.SessionData) -> int:
	var seed = int(session.battle.get("combat_seed", 0))
	if seed != 0:
		return seed
	return hash("%s:%s:%d" % [session.session_id, String(session.battle.get("encounter_id", "")), int(session.battle.get("round", 1))])

static func _battle_state_counter(session: SessionStateStoreScript.SessionData) -> int:
	return hash(JSON.stringify(session.battle))

static func _normalize_recent_events(value: Variant) -> Array:
	var events = []
	if value is Array:
		for entry in value:
			var text = String(entry).strip_edges()
			if text == "" or text in events:
				continue
			events.append(text)
			if events.size() >= RECENT_EVENT_LIMIT:
				break
	return events

static func _normalize_tactical_briefing_state(value: Variant, session: SessionStateStoreScript.SessionData) -> Dictionary:
	var signature = "%s|%s" % [
		String(session.battle.get("encounter_id", "")),
		String(session.battle.get("resolved_key", "")),
	]
	var briefing = value if value is Dictionary else {}
	if String(briefing.get("signature", "")) != signature:
		briefing = {
			"signature": signature,
			"shown": false,
			"shown_round": 0,
		}
	else:
		briefing = {
			"signature": signature,
			"shown": bool(briefing.get("shown", false)),
			"shown_round": max(0, int(briefing.get("shown_round", 0))),
		}
	var recent_events = session.battle.get("recent_events", [])
	if not bool(briefing.get("shown", false)) and (
		int(session.battle.get("round", 1)) > 1
		or (recent_events is Array and not recent_events.is_empty())
	):
		briefing["shown"] = true
		briefing["shown_round"] = max(1, int(session.battle.get("round", 1)))
	return briefing

static func _titleize_token(value: String) -> String:
	if value == "":
		return ""
	var words = value.split("_")
	for index in range(words.size()):
		words[index] = String(words[index]).capitalize()
	return " ".join(words)

static func _record_event(battle: Dictionary, message: String) -> void:
	if battle.is_empty():
		return
	var text = message.strip_edges()
	if text == "":
		return
	var events = _normalize_recent_events(battle.get("recent_events", []))
	for index in range(events.size() - 1, -1, -1):
		if String(events[index]) == text:
			events.remove_at(index)
	events.push_front(text)
	while events.size() > RECENT_EVENT_LIMIT:
		events.pop_back()
	battle["recent_events"] = events

static func _get_stack_by_id(battle: Dictionary, battle_id: String) -> Dictionary:
	if battle_id == "":
		return {}
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			return stack
	return {}

static func _stack_label(stack: Dictionary) -> String:
	return String(stack.get("name", stack.get("unit_id", "Stack")))

static func _stack_summary_line(stack: Dictionary, battle: Dictionary, active_id: String, selected_id: String) -> String:
	var markers = []
	if String(stack.get("battle_id", "")) == active_id:
		markers.append("ACT")
	if String(stack.get("battle_id", "")) == selected_id:
		markers.append("TGT")
	var count = _alive_count(stack)
	var role_summary = (
		"Shots %d" % int(stack.get("shots_remaining", 0))
		if bool(stack.get("ranged", false))
		else "Retal %d/%d" % [int(stack.get("retaliations_left", 0)), int(stack.get("retaliations", 0))]
	)
	var ability_summary = _stack_ability_summary(stack)
	var effect_summary = SpellRulesScript.effect_summary(stack, battle)
	var stance = " | Defending" if bool(stack.get("defending", false)) else ""
	return "%s%s x%d | HP %d | Atk %d Def %d Init %d | %s%s%s%s" % [
		("[%s] " % ",".join(markers)) if not markers.is_empty() else "",
		String(stack.get("name", stack.get("unit_id", ""))),
		count,
		int(stack.get("total_health", 0)),
		_stack_attack_total(stack, battle),
		_stack_defense_total(stack, battle),
		_stack_initiative_total(stack, battle),
		"%s | Coh %d Mom %d%s" % [
			role_summary,
			_stack_cohesion_total(stack, battle),
			_stack_momentum_total(stack, battle),
			" Iso" if _stack_is_isolated(battle, stack) else "",
		],
		stance,
		(" | %s" % ability_summary) if ability_summary != "" else "",
		(" | %s" % effect_summary) if effect_summary != "" else "",
	]
