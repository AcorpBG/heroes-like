class_name HeroCommandRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
static var DifficultyRulesScript: Variant = load("res://scripts/core/DifficultyRules.gd")

const HALL_BUILDING_ID := "building_wayfarers_hall"
const HOLDER_GARRISON := "garrison"
const HERO_LIMIT := 4
const DEFAULT_RECRUIT_COST := {"gold": 1200}
const BASE_SCOUT_RADIUS := 2

static func normalize_session(
	session: SessionStateStoreScript.SessionData,
	primary_hero_id: String = "",
	default_position: Dictionary = {},
	default_army: Dictionary = {}
) -> void:
	if session == null:
		return

	var scenario := ContentService.get_scenario(session.scenario_id)
	var resolved_primary_id := String(session.hero_id)
	if resolved_primary_id == "":
		resolved_primary_id = primary_hero_id if primary_hero_id != "" else String(scenario.get("hero_id", ""))
	session.hero_id = resolved_primary_id

	var legacy_hero = session.overworld.get("hero", {})
	var legacy_hero_id := String(legacy_hero.get("id", resolved_primary_id)) if legacy_hero is Dictionary else resolved_primary_id
	var legacy_position := _normalize_position(
		default_position if not default_position.is_empty() else session.overworld.get("hero_position", scenario.get("start", {"x": 0, "y": 0}))
	)
	var legacy_army := default_army if not default_army.is_empty() else _normalize_army(session.overworld.get("army", {}), legacy_hero_id)
	var legacy_movement = session.overworld.get("movement", {})

	var normalized_heroes := []
	var seen := {}
	var raw_player_heroes = session.overworld.get("player_heroes", [])
	if raw_player_heroes is Array:
		for hero_entry in raw_player_heroes:
			if not (hero_entry is Dictionary):
				continue
			var hero_id := String(hero_entry.get("id", ""))
			if hero_id == "" or seen.has(hero_id):
				continue
			var hero := _normalize_player_hero(
				hero_entry,
				session,
				legacy_position if hero_id == legacy_hero_id else {},
				legacy_army if hero_id == legacy_hero_id else {},
				legacy_movement if hero_id == legacy_hero_id else {}
			)
			if hero.is_empty():
				continue
			normalized_heroes.append(hero)
			seen[hero_id] = true

	if legacy_hero is Dictionary and not legacy_hero.is_empty():
		var normalized_legacy := _normalize_player_hero(
			legacy_hero,
			session,
			legacy_position,
			legacy_army,
			legacy_movement
		)
		if not normalized_legacy.is_empty():
			if seen.has(legacy_hero_id):
				_replace_hero_in_array(normalized_heroes, normalized_legacy)
			else:
				normalized_heroes.append(normalized_legacy)
				seen[legacy_hero_id] = true

	if resolved_primary_id != "" and not seen.has(resolved_primary_id):
		var primary_template := ContentService.get_hero(resolved_primary_id)
		var primary_hero := build_hero_from_template(primary_template, legacy_position, legacy_army, session)
		if not primary_hero.is_empty():
			primary_hero["is_primary"] = true
			normalized_heroes.append(primary_hero)
			seen[resolved_primary_id] = true

	if resolved_primary_id == "" and not normalized_heroes.is_empty():
		resolved_primary_id = String(normalized_heroes[0].get("id", ""))
		session.hero_id = resolved_primary_id

	for index in range(normalized_heroes.size()):
		var hero = normalized_heroes[index]
		hero["is_primary"] = String(hero.get("id", "")) == resolved_primary_id
		normalized_heroes[index] = hero

	session.overworld["player_heroes"] = normalized_heroes
	var active_hero_id := String(session.overworld.get("active_hero_id", legacy_hero_id))
	if active_hero_id == "" or _hero_index_by_id(normalized_heroes, active_hero_id) < 0:
		active_hero_id = resolved_primary_id
	if active_hero_id == "" and not normalized_heroes.is_empty():
		active_hero_id = String(normalized_heroes[0].get("id", ""))
	session.overworld["active_hero_id"] = active_hero_id
	_sync_active_hero_mirror(session)

static func build_hero_from_template(
	hero_template: Dictionary,
	position: Dictionary = {},
	army_state: Dictionary = {},
	movement_source: Variant = null
) -> Dictionary:
	if hero_template.is_empty():
		return {}
	var command = hero_template.get("command", {})
	var hero := HeroProgressionRulesScript.ensure_hero_progression(
		{
			"id": String(hero_template.get("id", "")),
			"name": String(hero_template.get("name", "Wandering Captain")),
			"level": 1,
			"experience": 0,
			"next_level_experience": 250,
			"base_movement": max(1, int(hero_template.get("base_movement", 10))),
			"command": {
				"attack": int(command.get("attack", 0)),
				"defense": int(command.get("defense", 0)),
				"power": int(command.get("power", 0)),
				"knowledge": int(command.get("knowledge", 0)),
			},
			"spellbook": SpellRulesScript.build_spellbook(hero_template),
			"artifacts": ArtifactRulesScript.normalize_hero_artifacts({}),
			"specialties": _normalize_authored_specialties(hero_template.get("starting_specialties", [])),
			"pending_specialty_choices": [],
			"specialty_focus_ids": _normalize_authored_specialties(hero_template.get("specialty_focus_ids", [])),
		}
	)
	hero["position"] = _normalize_position(position)
	hero["army"] = _normalize_army(army_state, String(hero.get("id", "")))
	var movement_max := movement_max_for_hero(hero, movement_source)
	hero["movement"] = {"current": movement_max, "max": movement_max}
	hero["is_primary"] = false
	return hero

static func movement_max_for_hero(hero_state: Dictionary, movement_source: Variant = null) -> int:
	var artifact_bonuses = ArtifactRulesScript.aggregate_bonuses(hero_state)
	var specialty_bonuses = HeroProgressionRulesScript.aggregate_bonuses(hero_state)
	var difficulty_bonus := 0
	if movement_source is SessionStateStoreScript.SessionData:
		difficulty_bonus = DifficultyRulesScript.movement_bonus(movement_source)
	else:
		var difficulty_id: String = DifficultyRulesScript.normalize_difficulty(String(movement_source))
		difficulty_bonus = int(DifficultyRulesScript.profile_for_difficulty(difficulty_id).get("movement_bonus", 0))
	return max(
		1,
		int(hero_state.get("base_movement", 10))
		+ max(0, int(hero_state.get("level", 1)) - 1)
		+ int(artifact_bonuses.get("overworld_movement", 0))
		+ int(specialty_bonuses.get("overworld_movement", 0))
		+ difficulty_bonus
	)

static func scouting_radius_for_hero(hero_state: Dictionary) -> int:
	var artifact_bonuses = ArtifactRulesScript.aggregate_bonuses(hero_state)
	var specialty_bonuses = HeroProgressionRulesScript.aggregate_bonuses(hero_state)
	return max(
		1,
		BASE_SCOUT_RADIUS
		+ int(artifact_bonuses.get("scouting_radius", 0))
		+ int(specialty_bonuses.get("scouting_radius", 0))
	)

static func active_hero(session: SessionStateStoreScript.SessionData) -> Dictionary:
	if session == null:
		return {}
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and String(hero.get("id", "")) == active_hero_id:
			return hero
	return {}

static func primary_hero(session: SessionStateStoreScript.SessionData) -> Dictionary:
	return primary_hero_from_overworld(session.overworld if session != null else {}, session.hero_id if session != null else "")

static func hero_by_id(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	if session == null or hero_id == "":
		return {}
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and String(hero.get("id", "")) == hero_id:
			return hero
	return {}

static func player_hero_count(session: SessionStateStoreScript.SessionData) -> int:
	return hero_count_from_overworld(session.overworld if session != null else {})

static func active_hero_is_primary(session: SessionStateStoreScript.SessionData) -> bool:
	var hero := active_hero(session)
	return not hero.is_empty() and bool(hero.get("is_primary", false))

static func spend_active_hero_movement(
	session: SessionStateStoreScript.SessionData,
	amount: int,
	reason: String = ""
) -> Dictionary:
	normalize_session(session)
	if amount <= 0:
		return {"ok": true, "message": "", "remaining_movement": int(session.overworld.get("movement", {}).get("current", 0))}
	commit_active_hero(session)
	var hero := active_hero(session)
	if hero.is_empty():
		return {"ok": false, "message": "No active commander is available."}
	var heroes = session.overworld.get("player_heroes", [])
	var hero_id := String(hero.get("id", ""))
	var hero_index := _hero_index_by_id(heroes, hero_id)
	if hero_index < 0:
		return {"ok": false, "message": "The active commander could not be synchronized."}

	var movement := _normalize_movement(hero.get("movement", {}), movement_max_for_hero(hero, session))
	var current := int(movement.get("current", 0))
	if current < amount:
		var reason_clause := " for %s" % reason if reason != "" else ""
		return {
			"ok": false,
			"message": "%s needs %d movement%s but only has %d left." % [
				String(hero.get("name", "The commander")),
				amount,
				reason_clause,
				current,
			],
		}

	movement["current"] = current - amount
	hero["movement"] = movement
	heroes[hero_index] = hero
	session.overworld["player_heroes"] = heroes
	_sync_active_hero_mirror(session)
	return {
		"ok": true,
		"message": "",
		"remaining_movement": int(movement.get("current", 0)),
	}

static func commit_active_hero(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var heroes = session.overworld.get("player_heroes", [])
	if not (heroes is Array) or heroes.is_empty():
		return
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var active_index := _hero_index_by_id(heroes, active_hero_id)
	if active_index < 0:
		return

	var committed = session.overworld.get("hero", {})
	if not (committed is Dictionary) or committed.is_empty():
		committed = heroes[active_index]
	committed = committed.duplicate(true)
	committed["position"] = _normalize_position(session.overworld.get("hero_position", committed.get("position", {})))
	committed["army"] = _normalize_army(session.overworld.get("army", committed.get("army", {})), String(committed.get("id", "")))
	committed["movement"] = _normalize_movement(
		session.overworld.get("movement", committed.get("movement", {})),
		movement_max_for_hero(committed, session)
	)
	committed = _normalize_player_hero(committed, session, committed.get("position", {}), committed.get("army", {}), committed.get("movement", {}))
	heroes[active_index] = committed
	session.overworld["player_heroes"] = heroes
	_sync_active_hero_mirror(session)

static func set_active_hero(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	normalize_session(session)
	if hero_id == "":
		return {"ok": false, "message": "No hero was selected."}
	commit_active_hero(session)
	var hero := hero_by_id(session, hero_id)
	if hero.is_empty():
		return {"ok": false, "message": "That hero is not under command."}
	if String(session.overworld.get("active_hero_id", "")) == hero_id:
		return {"ok": true, "message": "%s is already in command." % String(hero.get("name", "The hero"))}
	session.overworld["active_hero_id"] = hero_id
	_sync_active_hero_mirror(session)
	return {"ok": true, "message": "%s takes command." % String(hero.get("name", "The hero"))}

static func hero_template(payload: Dictionary) -> Dictionary:
	if payload.is_empty():
		return {}
	if payload.has("starting_spell_ids") and payload.has("faction_id"):
		return payload
	return ContentService.get_hero(String(payload.get("id", "")))

static func hero_archetype_label(payload: Dictionary) -> String:
	var template := hero_template(payload)
	var archetype := String(template.get("archetype", payload.get("archetype", "field captain")))
	return archetype.capitalize()

static func hero_identity_summary(payload: Dictionary) -> String:
	var template := hero_template(payload)
	return String(template.get("identity_summary", ""))

static func hero_profile_summary(payload: Dictionary, include_focus: bool = false) -> String:
	var template := hero_template(payload)
	if template.is_empty():
		return ""
	var parts := []
	var roster_summary := String(template.get("roster_summary", ""))
	if roster_summary != "":
		parts.append(roster_summary)
	else:
		parts.append(hero_archetype_label(template))
	var starting_specialties: String = HeroProgressionRulesScript.summarize_specialty_ids(template.get("starting_specialties", []))
	if starting_specialties != "":
		parts.append("Starts %s" % starting_specialties)
	if include_focus:
		var focus_specialties: String = HeroProgressionRulesScript.summarize_specialty_ids(template.get("specialty_focus_ids", []))
		if focus_specialties != "":
			parts.append("Focus %s" % focus_specialties)
	return " | ".join(parts)

static func describe_roster(session: SessionStateStoreScript.SessionData, stationed_only: bool = false, town: Dictionary = {}) -> String:
	normalize_session(session)
	var lines := ["Command"]
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var player_heroes = session.overworld.get("player_heroes", [])
	for hero in player_heroes:
		if not (hero is Dictionary):
			continue
		if stationed_only and not _hero_is_stationed_at_town(hero, town):
			continue
		lines.append("- %s" % _hero_roster_line(hero, active_hero_id))
	if lines.size() == 1:
		lines.append("- No stationed heroes")
	return "\n".join(lines)

static func get_overworld_switch_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_session(session)
	var actions := []
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	for hero in session.overworld.get("player_heroes", []):
		if not (hero is Dictionary):
			continue
		var hero_id := String(hero.get("id", ""))
		actions.append(
			{
				"id": "switch_hero:%s" % hero_id,
				"label": "Command %s" % String(hero.get("name", hero_id)),
				"summary": _hero_roster_line(hero, active_hero_id),
				"disabled": hero_id == active_hero_id,
			}
		)
	return actions

static func get_town_switch_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	normalize_session(session)
	var actions := []
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	for hero in stationed_heroes(session, town):
		var hero_id := String(hero.get("id", ""))
		actions.append(
			{
				"id": "switch_hero:%s" % hero_id,
				"label": "Command %s" % String(hero.get("name", hero_id)),
				"summary": _hero_roster_line(hero, active_hero_id),
				"disabled": hero_id == active_hero_id,
			}
		)
	return actions

static func stationed_heroes(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	var stationed := []
	if session == null or town.is_empty():
		return stationed
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and _hero_is_stationed_at_town(hero, town):
			stationed.append(hero)
	return stationed

static func describe_tavern(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	var hall_name := String(ContentService.get_building(HALL_BUILDING_ID).get("name", "Wayfarers Hall"))
	var lines := [hall_name]
	if not town_has_hall(town):
		lines.append("- Build %s to recruit additional commanders." % hall_name)
		return "\n".join(lines)
	if player_hero_count(session) >= HERO_LIMIT:
		lines.append("- The command roster is already full.")
		return "\n".join(lines)
	if recruitable_hero_ids(session).is_empty():
		lines.append("- No additional commanders are currently available for hire.")
		return "\n".join(lines)

	var actions := get_tavern_actions(session, town)
	if actions.is_empty():
		lines.append("- No commanders are currently available for hire.")
		return "\n".join(lines)

	for action in actions:
		if not (action is Dictionary):
			continue
		lines.append("- %s | %s" % [String(action.get("label", "")), String(action.get("summary", ""))])
	return "\n".join(lines)

static func get_tavern_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	normalize_session(session)
	var actions := []
	if session == null or town.is_empty() or not town_has_hall(town):
		return actions
	if player_hero_count(session) >= HERO_LIMIT:
		return actions

	for hero_id in recruitable_hero_ids(session):
		var hero_template := ContentService.get_hero(hero_id)
		if hero_template.is_empty():
			continue
		var cost := hero_recruit_cost(hero_template)
		actions.append(
			{
				"id": "hire_hero:%s" % hero_id,
				"label": "Hire %s" % String(hero_template.get("name", hero_id)),
				"summary": "%s | Cost %s" % [
					hero_profile_summary(hero_template, true),
					_describe_resources(cost),
				],
				"disabled": not _can_afford(session, cost),
			}
		)
	return actions

static func recruit_hero_at_town(session: SessionStateStoreScript.SessionData, town: Dictionary, hero_id: String) -> Dictionary:
	normalize_session(session)
	if session == null or town.is_empty():
		return {"ok": false, "message": "No town is available for hero recruitment."}
	if String(town.get("owner", "neutral")) != "player":
		return {"ok": false, "message": "Only controlled towns can hire new commanders."}
	if not town_has_hall(town):
		return {"ok": false, "message": "A Wayfarers Hall is required before a new commander can be hired."}
	if hero_id not in recruitable_hero_ids(session):
		return {"ok": false, "message": "That commander is not currently available for hire."}
	if player_hero_count(session) >= HERO_LIMIT:
		return {"ok": false, "message": "The command limit has already been reached."}

	var hero_template := ContentService.get_hero(hero_id)
	var cost := hero_recruit_cost(hero_template)
	if not _can_afford(session, cost):
		return {"ok": false, "message": "Insufficient resources to hire %s." % String(hero_template.get("name", hero_id))}

	_spend_resources(session, cost)
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	var hero := build_hero_from_template(hero_template, position, {"id": "%s_army" % hero_id, "name": "Field Army", "stacks": []}, session)
	var heroes = session.overworld.get("player_heroes", [])
	if not (heroes is Array):
		heroes = []
	heroes.append(hero)
	session.overworld["player_heroes"] = heroes
	normalize_session(session)
	var town_name := String(ContentService.get_town(String(town.get("town_id", ""))).get("name", town.get("town_id", "the town")))
	return {"ok": true, "message": "%s joins the command roster at %s." % [String(hero.get("name", hero_id)), town_name]}

static func describe_town_transfer(session: SessionStateStoreScript.SessionData, town: Dictionary) -> String:
	normalize_session(session)
	var lines := ["Transfer"]
	lines.append("- Garrison | %s" % _stack_summary_from_array(town.get("garrison", [])))
	for hero in stationed_heroes(session, town):
		lines.append("- %s | %s" % [String(hero.get("name", "Hero")), _army_summary(hero.get("army", {}))])
	return "\n".join(lines)

static func get_town_transfer_actions(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	normalize_session(session)
	var actions := []
	if session == null or town.is_empty():
		return actions
	var holders := _stationed_holder_ids(session, town)
	if holders.size() < 2:
		return actions

	for source_holder in holders:
		for target_holder in holders:
			if source_holder == target_holder:
				continue
			for stack in _holder_stacks(session, town, source_holder):
				if not (stack is Dictionary):
					continue
				var unit_id := String(stack.get("unit_id", ""))
				var count := int(stack.get("count", 0))
				if unit_id == "" or count <= 0:
					continue
				for amount_token in _transfer_amount_tokens(count):
					var amount_label := _transfer_amount_label(amount_token, count)
					var unit_name := String(ContentService.get_unit(unit_id).get("name", unit_id))
					actions.append(
						{
							"id": "transfer:%s:%s:%s:%s" % [source_holder, target_holder, unit_id, amount_token],
							"label": "Move %s %s" % [amount_label, unit_name],
							"summary": "%s -> %s" % [_holder_label(session, town, source_holder), _holder_label(session, town, target_holder)],
							"disabled": false,
						}
					)
	return actions

static func transfer_town_stack(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	source_holder: String,
	target_holder: String,
	unit_id: String,
	amount_token: String
) -> Dictionary:
	normalize_session(session)
	if session == null or town.is_empty():
		return {"ok": false, "message": "No town is available for army transfer."}
	if source_holder == target_holder:
		return {"ok": false, "message": "Choose a different transfer target."}
	var stationed_holders := _stationed_holder_ids(session, town)
	if source_holder not in stationed_holders or target_holder not in stationed_holders:
		return {"ok": false, "message": "Transfer orders are limited to the active town garrison and stationed heroes."}
	if unit_id == "":
		return {"ok": false, "message": "That transfer order is missing a unit id."}

	var source_stacks := _holder_stacks(session, town, source_holder)
	var source_index := _stack_index_by_unit(source_stacks, unit_id)
	if source_index < 0:
		return {"ok": false, "message": "That stack is no longer available for transfer."}
	var source_stack = source_stacks[source_index]
	var available := int(source_stack.get("count", 0))
	var transfer_count := _resolve_transfer_amount(amount_token, available)
	if transfer_count <= 0:
		return {"ok": false, "message": "No troops are available for transfer."}

	source_stack["count"] = available - transfer_count
	if int(source_stack.get("count", 0)) > 0:
		source_stacks[source_index] = source_stack
	else:
		source_stacks.remove_at(source_index)

	var target_stacks := _holder_stacks(session, town, target_holder)
	var target_index := _stack_index_by_unit(target_stacks, unit_id)
	if target_index >= 0:
		var target_stack = target_stacks[target_index]
		target_stack["count"] = int(target_stack.get("count", 0)) + transfer_count
		target_stacks[target_index] = target_stack
	else:
		target_stacks.append({"unit_id": unit_id, "count": transfer_count})

	_set_holder_stacks(session, town, source_holder, source_stacks)
	_set_holder_stacks(session, town, target_holder, target_stacks)
	commit_active_hero(session)

	var unit_name := String(ContentService.get_unit(unit_id).get("name", unit_id))
	return {
		"ok": true,
		"message": "Moved %d %s from %s to %s." % [
			transfer_count,
			unit_name,
			_holder_label(session, town, source_holder),
			_holder_label(session, town, target_holder),
		],
	}

static func remove_active_hero_after_defeat(session: SessionStateStoreScript.SessionData) -> Dictionary:
	normalize_session(session)
	commit_active_hero(session)
	if session == null:
		return {"ok": false, "message": "No active hero is available."}
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var removed_hero := hero_by_id(session, active_hero_id)
	if removed_hero.is_empty():
		return {"ok": false, "message": "No active hero is available."}
	if bool(removed_hero.get("is_primary", false)):
		return {"ok": false, "message": "The primary hero cannot be removed by this path."}

	var remaining := []
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and String(hero.get("id", "")) != active_hero_id:
			remaining.append(hero)
	session.overworld["player_heroes"] = remaining
	var next_active_id := String(session.hero_id)
	if _hero_index_by_id(remaining, next_active_id) < 0 and not remaining.is_empty():
		next_active_id = String(remaining[0].get("id", ""))
	session.overworld["active_hero_id"] = next_active_id
	_sync_active_hero_mirror(session)
	return {
		"ok": true,
		"message": "%s falls in battle." % String(removed_hero.get("name", "The hero")),
		"removed_hero_name": String(removed_hero.get("name", "The hero")),
		"next_active_name": String(active_hero(session).get("name", "")),
	}

static func town_has_hall(town: Dictionary) -> bool:
	return HALL_BUILDING_ID in town.get("built_buildings", [])

static func hero_recruit_cost(hero_template: Dictionary) -> Dictionary:
	var cost = hero_template.get("recruit_cost", DEFAULT_RECRUIT_COST)
	return _normalize_resources(cost)

static func recruitable_hero_ids(session: SessionStateStoreScript.SessionData) -> Array:
	var recruitable := []
	if session == null:
		return recruitable
	var scenario := ContentService.get_scenario(session.scenario_id)
	var player_faction := ContentService.get_faction(String(scenario.get("player_faction_id", "")))
	var controlled := {}
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary:
			controlled[String(hero.get("id", ""))] = true
	for hero_id_value in player_faction.get("hero_ids", []):
		var hero_id := String(hero_id_value)
		if hero_id == "" or controlled.has(hero_id):
			continue
		if not _hero_recruitable_for_scenario(hero_id, scenario):
			continue
		recruitable.append(hero_id)
	recruitable.sort()
	return recruitable

static func _hero_recruitable_for_scenario(hero_id: String, scenario: Dictionary) -> bool:
	var hero := ContentService.get_hero(hero_id)
	if hero.is_empty():
		return false
	if String(hero.get("roster_state", "live")) != "scaffold":
		return true
	if bool(scenario.get("allow_scaffold_roster", false)):
		return true
	for start_id_value in scenario.get("hero_starts", []):
		if String(start_id_value) == hero_id:
			return true
	return false

static func primary_hero_from_overworld(overworld_state: Variant, primary_hero_id: String = "") -> Dictionary:
	if overworld_state is Dictionary:
		var player_heroes = overworld_state.get("player_heroes", [])
		if player_heroes is Array:
			for hero in player_heroes:
				if hero is Dictionary and bool(hero.get("is_primary", false)):
					return hero
			for hero in player_heroes:
				if hero is Dictionary and String(hero.get("id", "")) == primary_hero_id:
					return hero
			for hero in player_heroes:
				if hero is Dictionary:
					return hero
		var hero = overworld_state.get("hero", {})
		if hero is Dictionary:
			return hero
	return {}

static func active_hero_from_overworld(overworld_state: Variant) -> Dictionary:
	if overworld_state is Dictionary:
		var active_hero_id := String(overworld_state.get("active_hero_id", ""))
		var player_heroes = overworld_state.get("player_heroes", [])
		if player_heroes is Array:
			for hero in player_heroes:
				if hero is Dictionary and String(hero.get("id", "")) == active_hero_id:
					return hero
		var hero = overworld_state.get("hero", {})
		if hero is Dictionary:
			return hero
	return {}

static func hero_count_from_overworld(overworld_state: Variant) -> int:
	if overworld_state is Dictionary and overworld_state.get("player_heroes", []) is Array:
		return int(overworld_state.get("player_heroes", []).size())
	if overworld_state is Dictionary and overworld_state.get("hero", {}) is Dictionary and not overworld_state.get("hero", {}).is_empty():
		return 1
	return 0

static func closest_hero_target(session: SessionStateStoreScript.SessionData, origin: Vector2i = Vector2i.ZERO) -> Dictionary:
	normalize_session(session)
	var best := {}
	for hero in session.overworld.get("player_heroes", []):
		if not (hero is Dictionary):
			continue
		var position := _normalize_position(hero.get("position", {}))
		var distance: int = abs(origin.x - int(position.get("x", 0))) + abs(origin.y - int(position.get("y", 0)))
		if best.is_empty() or distance < int(best.get("distance", 9999)):
			best = {
				"id": String(hero.get("id", "")),
				"name": String(hero.get("name", "the hero")),
				"x": int(position.get("x", 0)),
				"y": int(position.get("y", 0)),
				"distance": distance,
			}
	return best

static func hero_position_by_id(session: SessionStateStoreScript.SessionData, hero_id: String) -> Dictionary:
	var hero := hero_by_id(session, hero_id)
	return _normalize_position(hero.get("position", {}))

static func hero_positions(session: SessionStateStoreScript.SessionData) -> Array:
	var positions := []
	if session == null:
		return positions
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary:
			positions.append(
				{
					"id": String(hero.get("id", "")),
					"name": String(hero.get("name", "Hero")),
					"x": int(hero.get("position", {}).get("x", 0)),
					"y": int(hero.get("position", {}).get("y", 0)),
					"is_active": String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")),
				}
			)
	return positions

static func _normalize_player_hero(
	hero_state: Dictionary,
	session: SessionStateStoreScript.SessionData,
	fallback_position: Dictionary,
	fallback_army: Dictionary,
	fallback_movement: Variant
) -> Dictionary:
	var hero_id := String(hero_state.get("id", ""))
	if hero_id == "":
		return {}
	var hero_template := ContentService.get_hero(hero_id)
	var hero := hero_state.duplicate(true)
	hero["id"] = hero_id
	hero["name"] = String(hero.get("name", hero_template.get("name", hero_id)))
	hero["base_movement"] = max(1, int(hero.get("base_movement", hero_template.get("base_movement", 10))))
	hero["specialty_focus_ids"] = _normalize_authored_specialties(
		hero.get("specialty_focus_ids", hero_template.get("specialty_focus_ids", []))
	)
	if int(hero.get("level", 1)) <= 1 and int(hero.get("experience", 0)) == 0:
		var starting_specialties := _normalize_authored_specialties(hero_template.get("starting_specialties", []))
		if not starting_specialties.is_empty() and _normalize_authored_specialties(hero.get("specialties", [])).is_empty():
			hero["specialties"] = starting_specialties
	hero = HeroProgressionRulesScript.ensure_hero_progression(hero)
	hero = SpellRulesScript.ensure_hero_spellbook(hero, hero_template)
	hero = ArtifactRulesScript.ensure_hero_artifacts(hero)
	hero["position"] = _normalize_position(hero.get("position", fallback_position))
	hero["army"] = _normalize_army(hero.get("army", fallback_army), hero_id)
	hero["movement"] = _normalize_movement(hero.get("movement", fallback_movement), movement_max_for_hero(hero, session))
	return hero

static func _sync_active_hero_mirror(session: SessionStateStoreScript.SessionData) -> void:
	if session == null:
		return
	var hero := active_hero(session)
	if hero.is_empty():
		session.overworld["hero"] = {}
		session.overworld["army"] = {}
		session.overworld["movement"] = {}
		session.overworld["hero_position"] = {}
		return
	session.overworld["hero"] = hero
	session.overworld["army"] = hero.get("army", {})
	session.overworld["movement"] = hero.get("movement", {})
	session.overworld["hero_position"] = hero.get("position", {})

static func _replace_hero_in_array(player_heroes: Array, replacement: Dictionary) -> void:
	var replacement_id := String(replacement.get("id", ""))
	for index in range(player_heroes.size()):
		var hero = player_heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == replacement_id:
			player_heroes[index] = replacement
			return

static func _hero_index_by_id(player_heroes: Array, hero_id: String) -> int:
	for index in range(player_heroes.size()):
		var hero = player_heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == hero_id:
			return index
	return -1

static func _normalize_position(value: Variant) -> Dictionary:
	if value is Dictionary:
		return {"x": int(value.get("x", 0)), "y": int(value.get("y", 0))}
	if value is Vector2i:
		return {"x": value.x, "y": value.y}
	return {"x": 0, "y": 0}

static func _normalize_movement(value: Variant, movement_max: int) -> Dictionary:
	var normalized := {"current": movement_max, "max": movement_max}
	if value is Dictionary:
		normalized["current"] = clamp(int(value.get("current", movement_max)), 0, movement_max)
	return normalized

static func _normalize_army(value: Variant, hero_id: String = "") -> Dictionary:
	var stacks := []
	if value is Dictionary:
		for stack in value.get("stacks", []):
			if not (stack is Dictionary):
				continue
			var unit_id := String(stack.get("unit_id", ""))
			var count := int(max(0, int(stack.get("count", 0))))
			if unit_id == "" or count <= 0:
				continue
			stacks.append({"unit_id": unit_id, "count": count})
	return {
		"id": String((value if value is Dictionary else {}).get("id", "%s_army" % hero_id)),
		"name": String((value if value is Dictionary else {}).get("name", "Field Army")),
		"stacks": stacks,
	}

static func _hero_roster_line(hero: Dictionary, active_hero_id: String) -> String:
	var tags := []
	if bool(hero.get("is_primary", false)):
		tags.append("Primary")
	if String(hero.get("id", "")) == active_hero_id:
		tags.append("Active")
	var position := _normalize_position(hero.get("position", {}))
	var movement = hero.get("movement", {})
	return "%s | %s%sPos %d,%d | Move %d/%d | %s" % [
		String(hero.get("name", "Hero")),
		", ".join(tags) + " | " if not tags.is_empty() else "",
		"",
		int(position.get("x", 0)),
		int(position.get("y", 0)),
		int(movement.get("current", 0)),
		int(movement.get("max", 0)),
		"Scout %d | %s | %s" % [
			scouting_radius_for_hero(hero),
			_army_summary(hero.get("army", {})),
			HeroProgressionRulesScript.brief_summary(hero),
		],
	]

static func _normalize_authored_specialties(value: Variant) -> Array:
	var normalized := []
	if value is Array:
		for specialty_id_value in value:
			var specialty_id := String(specialty_id_value)
			if HeroProgressionRulesScript.specialty_definition(specialty_id).is_empty() or specialty_id in normalized:
				continue
			normalized.append(specialty_id)
	return normalized

static func _army_summary(army: Variant) -> String:
	var stacks = army.get("stacks", []) if army is Dictionary else []
	return _stack_summary_from_array(stacks)

static func _stack_summary_from_array(stacks: Variant) -> String:
	if not (stacks is Array):
		return "No troops"
	var parts := []
	for stack in stacks:
		if not (stack is Dictionary):
			continue
		var count := int(stack.get("count", 0))
		if count <= 0:
			continue
		var unit_id := String(stack.get("unit_id", ""))
		var unit_name := String(ContentService.get_unit(unit_id).get("name", unit_id))
		parts.append("%s x%d" % [unit_name, count])
	return ", ".join(parts) if not parts.is_empty() else "No troops"

static func _hero_is_stationed_at_town(hero: Dictionary, town: Dictionary) -> bool:
	return int(hero.get("position", {}).get("x", -1)) == int(town.get("x", -2)) and int(hero.get("position", {}).get("y", -1)) == int(town.get("y", -2))

static func _stationed_holder_ids(session: SessionStateStoreScript.SessionData, town: Dictionary) -> Array:
	var holders := [HOLDER_GARRISON]
	for hero in stationed_heroes(session, town):
		holders.append(String(hero.get("id", "")))
	return holders

static func _holder_stacks(session: SessionStateStoreScript.SessionData, town: Dictionary, holder_id: String) -> Array:
	if holder_id == HOLDER_GARRISON:
		return town.get("garrison", []).duplicate(true) if town.get("garrison", []) is Array else []
	var hero := hero_by_id(session, holder_id)
	return hero.get("army", {}).get("stacks", []).duplicate(true) if not hero.is_empty() and hero.get("army", {}).get("stacks", []) is Array else []

static func _set_holder_stacks(session: SessionStateStoreScript.SessionData, town: Dictionary, holder_id: String, stacks: Array) -> void:
	if session == null or town.is_empty():
		return
	if holder_id == HOLDER_GARRISON:
		var towns = session.overworld.get("towns", [])
		for index in range(towns.size()):
			var entry = towns[index]
			if not (entry is Dictionary):
				continue
			if String(entry.get("placement_id", "")) != String(town.get("placement_id", "")):
				continue
			entry["garrison"] = stacks
			town["garrison"] = stacks
			towns[index] = entry
			session.overworld["towns"] = towns
			return
		return

	var heroes = session.overworld.get("player_heroes", [])
	var hero_index := _hero_index_by_id(heroes, holder_id)
	if hero_index < 0:
		return
	var hero = heroes[hero_index]
	var army = _normalize_army(hero.get("army", {}), holder_id)
	army["stacks"] = stacks
	hero["army"] = army
	heroes[hero_index] = hero
	session.overworld["player_heroes"] = heroes
	if String(session.overworld.get("active_hero_id", "")) == holder_id:
		_sync_active_hero_mirror(session)

static func _stack_index_by_unit(stacks: Array, unit_id: String) -> int:
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			return index
	return -1

static func _transfer_amount_tokens(count: int) -> Array:
	if count <= 0:
		return []
	var tokens := ["1"]
	if count > 1:
		tokens.append("half")
		tokens.append("all")
	return tokens

static func _transfer_amount_label(amount_token: String, available: int) -> String:
	match amount_token:
		"all":
			return "all"
		"half":
			return "half"
		_:
			return str(_resolve_transfer_amount(amount_token, available))

static func _resolve_transfer_amount(amount_token: String, available: int) -> int:
	if available <= 0:
		return 0
	match amount_token:
		"all":
			return available
		"half":
			return max(1, int(floor(float(available) / 2.0)))
		_:
			return clamp(int(amount_token), 0, available)

static func _holder_label(session: SessionStateStoreScript.SessionData, town: Dictionary, holder_id: String) -> String:
	if holder_id == HOLDER_GARRISON:
		return "%s garrison" % String(ContentService.get_town(String(town.get("town_id", ""))).get("name", town.get("town_id", "Town")))
	var hero := hero_by_id(session, holder_id)
	return String(hero.get("name", holder_id))

static func _can_afford(session: SessionStateStoreScript.SessionData, cost: Variant) -> bool:
	var resources = session.overworld.get("resources", {})
	if not (cost is Dictionary):
		return true
	for key in cost.keys():
		if int(resources.get(String(key), 0)) < int(cost[key]):
			return false
	return true

static func _spend_resources(session: SessionStateStoreScript.SessionData, cost: Variant) -> void:
	var resources = session.overworld.get("resources", {}).duplicate(true)
	if cost is Dictionary:
		for key in cost.keys():
			var resource_key := String(key)
			resources[resource_key] = max(0, int(resources.get(resource_key, 0)) - int(cost[key]))
	session.overworld["resources"] = resources

static func _normalize_resources(value: Variant) -> Dictionary:
	var resources := {}
	if value is Dictionary:
		for key in value.keys():
			var resource_key := String(key)
			var amount := int(max(0, int(value[key])))
			if amount > 0:
				resources[resource_key] = amount
	return resources

static func _describe_resources(resources: Variant) -> String:
	var normalized := _normalize_resources(resources)
	var parts := []
	for key in ["gold", "wood", "ore"]:
		var amount := int(normalized.get(key, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, key])
	return ", ".join(parts) if not parts.is_empty() else "free"
