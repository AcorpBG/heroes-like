class_name HeroCommandRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const OverworldLevelRulesScript = preload("res://scripts/core/OverworldLevelRules.gd")
const HeroProgressionRulesScript = preload("res://scripts/core/HeroProgressionRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")
const ArtifactRulesScript = preload("res://scripts/core/ArtifactRules.gd")
static var DifficultyRulesScript: Variant = load("res://scripts/core/DifficultyRules.gd")

const HALL_BUILDING_ID := "building_wayfarers_hall"
const HOLDER_GARRISON := "garrison"
const HERO_LIMIT := 4
const ARMY_SLOT_COUNT := 7
const ARMY_SLOT_INDEX_KEY := "slot_index"
const DEFAULT_RECRUIT_COST := {"gold": 1200}
const BASE_SCOUT_RADIUS := 3

static func normalize_session(
	session: SessionStateStoreScript.SessionData,
	primary_hero_id: String = "",
	default_position: Dictionary = {},
	default_army: Dictionary = {}
) -> void:
	if session == null:
		return

	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
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
		if String(session.overworld.get("active_player_id", "")) != "":
			hero["player_id"] = String(session.overworld.active_player_id)
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
	if movement_source is SessionStateStoreScript.SessionData and String(movement_source.overworld.get("active_player_id", "")) != "":
		hero["player_id"] = String(movement_source.overworld.active_player_id)
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

static func hero_faction_label(payload: Dictionary, fallback_faction_id: String = "") -> String:
	var template := hero_template(payload)
	var faction_id := String(payload.get("faction_id", template.get("faction_id", fallback_faction_id)))
	if faction_id == "":
		return "Free Banner"
	var faction := ContentService.get_faction(faction_id)
	return String(faction.get("name", faction_id))

static func hero_identity_summary(payload: Dictionary) -> String:
	var template := hero_template(payload)
	return String(template.get("identity_summary", ""))

static func hero_role_label(payload: Dictionary) -> String:
	var template := hero_template(payload)
	var roster_summary := String(template.get("roster_summary", payload.get("roster_summary", "")))
	if roster_summary != "":
		return roster_summary
	return hero_archetype_label(payload)

static func hero_identity_context_line(payload: Dictionary, fallback_faction_id: String = "") -> String:
	return "%s | %s | %s" % [
		String(payload.get("name", hero_template(payload).get("name", "Field Commander"))),
		hero_faction_label(payload, fallback_faction_id),
		hero_role_label(payload),
	]

static func hero_progress_context_line(hero_state: Dictionary) -> String:
	var hero := HeroProgressionRulesScript.ensure_hero_progression(hero_state.duplicate(true))
	var summary := HeroProgressionRulesScript.brief_summary(hero)
	if summary == "":
		summary = "No specialty"
	return "Lv%d | XP %d/%d | %s" % [
		int(hero.get("level", 1)),
		int(hero.get("experience", 0)),
		int(hero.get("next_level_experience", 250)),
		summary,
	]

static func hero_readiness_context_line(hero_state: Dictionary, include_position: bool = false) -> String:
	var parts := []
	if include_position:
		var position := _normalize_position(hero_state.get("position", {}))
		parts.append("Pos %d,%d" % [int(position.get("x", 0)), int(position.get("y", 0))])
	var movement = hero_state.get("movement", {})
	if movement is Dictionary and not movement.is_empty():
		parts.append("Move %d/%d" % [int(movement.get("current", 0)), int(movement.get("max", 0))])
	var mana = hero_state.get("spellbook", {}).get("mana", {})
	if mana is Dictionary and int(mana.get("max", 0)) > 0:
		parts.append("Mana %d/%d" % [int(mana.get("current", 0)), int(mana.get("max", 0))])
	var army_totals := _army_count_summary(hero_state.get("army", {}))
	parts.append(
		"Scout %d | %s"
		% [
			scouting_radius_for_hero(hero_state),
			"Army %d/%d" % [int(army_totals.get("troops", 0)), int(army_totals.get("groups", 0))],
		]
	)
	var command = hero_state.get("command", {})
	parts.append(
		"A%d D%d P%d K%d"
		% [
			int(command.get("attack", 0)),
			int(command.get("defense", 0)),
			int(command.get("power", 0)),
			int(command.get("knowledge", 0)),
		]
	)
	return " | ".join(parts)

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
	var position := OverworldLevelRulesScript.town_entrance(town)
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
				var admission := army_addition_plan(_holder_stacks(session, town, target_holder), {unit_id: 1})
				for amount_token in _transfer_amount_tokens(count):
					var amount_label := _transfer_amount_label(amount_token, count)
					var unit_name := String(ContentService.get_unit(unit_id).get("name", unit_id))
					actions.append(
						{
							"id": "transfer:%s:%s:%s:%s" % [source_holder, target_holder, unit_id, amount_token],
							"label": "Move %s %s" % [amount_label, unit_name],
							"summary": "%s -> %s%s" % [_holder_label(session, town, source_holder), _holder_label(session, town, target_holder), " | " + String(admission.get("message", "")) if not bool(admission.get("ok", false)) else ""],
							"disabled": not bool(admission.get("ok", false)),
						}
					)
	return actions

static func army_addition_plan(stacks_value: Variant, additions: Dictionary) -> Dictionary:
	# Plan before charging, consuming rewards or removing source troops. A
	# rejected manifest must never discard troops, including legacy excess.
	var stacks: Array = stacks_value.duplicate(true) if stacks_value is Array else []
	var occupied := _valid_stack_count(stacks)
	if occupied <= ARMY_SLOT_COUNT:
		stacks = _slotted_stacks(stacks)
	var unit_ids := additions.keys()
	unit_ids.sort()
	for unit_id_value in unit_ids:
		var unit_id := String(unit_id_value)
		var amount := maxi(0, int(additions.get(unit_id_value, 0)))
		if unit_id == "" or amount == 0:
			continue
		var matching := -1
		for index in range(stacks.size()):
			if stacks[index] is Dictionary and String(stacks[index].get("unit_id", "")) == unit_id and int(stacks[index].get("count", 0)) > 0:
				matching = index
				break
		if matching >= 0:
			stacks[matching]["count"] = int(stacks[matching].get("count", 0)) + amount
			continue
		if occupied >= ARMY_SLOT_COUNT:
			return {"ok": false, "reason": "army_capacity", "message": "All seven army slots are occupied. Transfer or merge troops before adding a new unit type."}
		var claimed := {}
		for stack in stacks:
			claimed[int(stack.get(ARMY_SLOT_INDEX_KEY, -1))] = true
		stacks.append({"unit_id": unit_id, "count": amount, ARMY_SLOT_INDEX_KEY: _first_open_army_slot(claimed)})
		occupied += 1
	return {"ok": true, "stacks": stacks}

static func army_slot_snapshot(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	holder_id: String
) -> Dictionary:
	normalize_session(session)
	if session == null or holder_id == "":
		return {}
	if not _army_slot_holder_is_available(session, town, holder_id):
		return {}
	var holder_stacks := _holder_stacks(session, town, holder_id)
	var occupied_count := _valid_stack_count(holder_stacks)
	var overflow_stacks := []
	var troop_count := 0
	var valid_index := 0
	for stack in holder_stacks:
		if not (stack is Dictionary) or String(stack.get("unit_id", "")) == "" or int(stack.get("count", 0)) <= 0:
			continue
		troop_count += int(stack.get("count", 0))
		if valid_index >= ARMY_SLOT_COUNT:
			var unit_id := String(stack.get("unit_id", ""))
			overflow_stacks.append({"unit_id": unit_id, "unit_name": String(ContentService.get_unit(unit_id).get("name", unit_id)), "count": int(stack.get("count", 0))})
		valid_index += 1
	var stacks := _slotted_stacks(holder_stacks)
	var by_slot := {}
	for stack_value in stacks:
		if not (stack_value is Dictionary):
			continue
		var stack: Dictionary = stack_value
		by_slot[int(stack.get(ARMY_SLOT_INDEX_KEY, -1))] = stack
	var slots := []
	for slot_index in range(ARMY_SLOT_COUNT):
		var stack: Dictionary = by_slot.get(slot_index, {})
		var unit_id := String(stack.get("unit_id", ""))
		var count := int(stack.get("count", 0))
		if unit_id == "" or count <= 0:
			slots.append({
				"slot_index": slot_index,
				"occupied": false,
				"holder_id": holder_id,
			})
			continue
		var unit := ContentService.get_unit(unit_id)
		var art := ContentService.get_unit_art(unit_id)
		slots.append({
			"slot_index": slot_index,
			"occupied": true,
			"holder_id": holder_id,
			"unit_id": unit_id,
			"unit_name": String(unit.get("name", unit_id)),
			"count": count,
			"tier": clampi(int(unit.get("tier", 1)), 1, 7),
			"role": String(unit.get("role", "")),
			"battle_icon": String(art.get("battle_icon", "")),
			"portrait": String(art.get("portrait", "")),
		})
	return {
		"model": "authoritative_seven_slot_army_bar",
		"holder_id": holder_id,
		"holder_label": _holder_label(session, town, holder_id),
		"slot_count": ARMY_SLOT_COUNT,
		"capacity_valid": occupied_count <= ARMY_SLOT_COUNT,
		"occupied_slot_count": occupied_count,
		"overflow_stack_count": overflow_stacks.size(),
		"overflow_stacks": overflow_stacks,
		"message": "%d stacks exceed the seven-slot limit. Open Town Log & Logistics and use Transfers to reduce this army; no troops were removed." % occupied_count if occupied_count > ARMY_SLOT_COUNT else "",
		"troop_count": troop_count,
		"slots": slots,
	}

static func manage_army_slots(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	source_holder_id: String,
	source_slot_index: int,
	target_holder_id: String,
	target_slot_index: int,
	amount_token: String = "all"
) -> Dictionary:
	normalize_session(session)
	if session == null:
		return {"ok": false, "message": "No expedition is available for army management."}
	if not _army_slot_holder_is_available(session, town, source_holder_id) or not _army_slot_holder_is_available(session, town, target_holder_id):
		return {"ok": false, "message": "Army management is limited to the active commander or holders stationed in this town."}
	if town.is_empty() and (source_holder_id != target_holder_id or source_holder_id != String(session.overworld.get("active_hero_id", ""))):
		return {"ok": false, "message": "Field arrangement is limited to the active commander's own formation."}
	if source_slot_index < 0 or source_slot_index >= ARMY_SLOT_COUNT or target_slot_index < 0 or target_slot_index >= ARMY_SLOT_COUNT:
		return {"ok": false, "message": "Choose two valid army slots."}
	if source_holder_id == target_holder_id and source_slot_index == target_slot_index:
		return {"ok": false, "message": "Choose a different destination slot."}
	if _valid_stack_count(_holder_stacks(session, town, source_holder_id)) > ARMY_SLOT_COUNT or _valid_stack_count(_holder_stacks(session, town, target_holder_id)) > ARMY_SLOT_COUNT:
		return {"ok": false, "message": "Army management is blocked because a holder exceeds the seven-stack formation capacity."}

	var source_stacks := _slotted_stacks(_holder_stacks(session, town, source_holder_id))
	var target_stacks := source_stacks.duplicate(true) if source_holder_id == target_holder_id else _slotted_stacks(_holder_stacks(session, town, target_holder_id))
	var source_array_index := _stack_index_by_slot(source_stacks, source_slot_index)
	if source_array_index < 0:
		return {"ok": false, "message": "Select an occupied source slot first."}
	var target_array_index := _stack_index_by_slot(target_stacks, target_slot_index)
	var source_stack: Dictionary = source_stacks[source_array_index].duplicate(true)
	var available := int(source_stack.get("count", 0))
	var transfer_count := _resolve_transfer_amount(amount_token, available)
	if transfer_count <= 0:
		return {"ok": false, "message": "That split amount leaves no troops to move."}
	var target_stack: Dictionary = target_stacks[target_array_index].duplicate(true) if target_array_index >= 0 else {}
	var same_unit := not target_stack.is_empty() and String(target_stack.get("unit_id", "")) == String(source_stack.get("unit_id", ""))
	if not target_stack.is_empty() and not same_unit and transfer_count != available:
		return {"ok": false, "message": "Split stacks can move only into an empty slot or merge with the same unit."}

	var operation := "move"
	if source_holder_id == target_holder_id:
		if target_stack.is_empty():
			if transfer_count == available:
				source_stack[ARMY_SLOT_INDEX_KEY] = target_slot_index
				source_stacks[source_array_index] = source_stack
			else:
				source_stack["count"] = available - transfer_count
				source_stacks[source_array_index] = source_stack
				var split_stack := source_stack.duplicate(true)
				split_stack["count"] = transfer_count
				split_stack[ARMY_SLOT_INDEX_KEY] = target_slot_index
				source_stacks.append(split_stack)
				operation = "split"
		elif same_unit:
			target_stack["count"] = int(target_stack.get("count", 0)) + transfer_count
			source_stacks[target_array_index] = target_stack
			if transfer_count == available:
				source_stacks.remove_at(source_array_index)
			else:
				source_stack["count"] = available - transfer_count
				source_stacks[source_array_index] = source_stack
			operation = "merge"
		else:
			var source_slot := int(source_stack.get(ARMY_SLOT_INDEX_KEY, source_slot_index))
			source_stack[ARMY_SLOT_INDEX_KEY] = target_slot_index
			target_stack[ARMY_SLOT_INDEX_KEY] = source_slot
			source_stacks[source_array_index] = source_stack
			source_stacks[target_array_index] = target_stack
			operation = "swap"
		target_stacks = source_stacks
	else:
		if target_stack.is_empty():
			var moved_stack := source_stack.duplicate(true)
			moved_stack["count"] = transfer_count
			moved_stack[ARMY_SLOT_INDEX_KEY] = target_slot_index
			target_stacks.append(moved_stack)
			operation = "move" if transfer_count == available else "split"
		elif same_unit:
			target_stack["count"] = int(target_stack.get("count", 0)) + transfer_count
			target_stacks[target_array_index] = target_stack
			operation = "merge"
		else:
			var target_slot := int(target_stack.get(ARMY_SLOT_INDEX_KEY, target_slot_index))
			target_stack[ARMY_SLOT_INDEX_KEY] = source_slot_index
			source_stack[ARMY_SLOT_INDEX_KEY] = target_slot
			target_stacks[target_array_index] = source_stack
			source_stacks[source_array_index] = target_stack
			operation = "swap"
		if operation != "swap":
			if transfer_count == available:
				source_stacks.remove_at(source_array_index)
			else:
				source_stack["count"] = available - transfer_count
				source_stacks[source_array_index] = source_stack

	source_stacks = _slotted_stacks(source_stacks)
	target_stacks = source_stacks if source_holder_id == target_holder_id else _slotted_stacks(target_stacks)
	_set_holder_stacks(session, town, source_holder_id, source_stacks)
	if source_holder_id != target_holder_id:
		_set_holder_stacks(session, town, target_holder_id, target_stacks)
	commit_active_hero(session)
	var unit_id := String(source_stack.get("unit_id", ""))
	var unit_name := String(ContentService.get_unit(unit_id).get("name", unit_id))
	return {
		"ok": true,
		"operation": operation,
		"message": "%s %d %s: %s slot %d -> %s slot %d." % [
			operation.capitalize(), transfer_count, unit_name,
			_holder_label(session, town, source_holder_id), source_slot_index + 1,
			_holder_label(session, town, target_holder_id), target_slot_index + 1,
		],
		"source_holder_id": source_holder_id,
		"source_slot_index": source_slot_index,
		"target_holder_id": target_holder_id,
		"target_slot_index": target_slot_index,
		"unit_id": unit_id,
		"moved_count": transfer_count,
		"source": army_slot_snapshot(session, town, source_holder_id),
		"target": army_slot_snapshot(session, town, target_holder_id),
	}

static func field_rendezvous_heroes(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_session(session)
	var rendezvous := []
	if session == null:
		return rendezvous
	var active := active_hero(session)
	if active.is_empty():
		return rendezvous
	var active_id := String(active.get("id", ""))
	var active_position := _normalize_position(active.get("position", {}))
	for hero_value in session.overworld.get("player_heroes", []):
		if not (hero_value is Dictionary):
			continue
		var hero: Dictionary = hero_value
		if String(hero.get("id", "")) == active_id:
			continue
		if _normalize_position(hero.get("position", {})) == active_position:
			rendezvous.append(hero)
	return rendezvous

static func describe_field_rendezvous(session: SessionStateStoreScript.SessionData) -> String:
	var active := active_hero(session)
	var rendezvous := field_rendezvous_heroes(session)
	if active.is_empty() or rendezvous.is_empty():
		return "No friendly commander is present for a field rendezvous."
	var lines := ["Field Rendezvous", "- Active: %s | %s | Gear %d | Spells %d" % [
		String(active.get("name", "Commander")),
		_army_summary(active.get("army", {})),
		ArtifactRulesScript.owned_artifact_ids(active).size(),
		SpellRulesScript.known_spells(active).size(),
	]]
	for hero_value in rendezvous:
		var hero: Dictionary = hero_value if hero_value is Dictionary else {}
		lines.append("- Reserve: %s | %s | Gear %d | Spells %d" % [
			String(hero.get("name", "Commander")),
			_army_summary(hero.get("army", {})),
			ArtifactRulesScript.owned_artifact_ids(hero).size(),
			SpellRulesScript.known_spells(hero).size(),
		])
	return "\n".join(lines)

static func get_field_transfer_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_session(session)
	var actions := []
	if session == null:
		return actions
	var active := active_hero(session)
	if active.is_empty():
		return actions
	for reserve_value in field_rendezvous_heroes(session):
		if not (reserve_value is Dictionary):
			continue
		var reserve: Dictionary = reserve_value
		_append_field_transfer_actions(actions, active, reserve)
		_append_field_transfer_actions(actions, reserve, active)
	return actions

static func get_field_artifact_transfer_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_session(session)
	var actions := []
	if session == null:
		return actions
	var active := active_hero(session)
	if active.is_empty():
		return actions
	for reserve_value in field_rendezvous_heroes(session):
		if not (reserve_value is Dictionary):
			continue
		var reserve: Dictionary = reserve_value
		_append_field_artifact_transfer_actions(actions, active, reserve)
		_append_field_artifact_transfer_actions(actions, reserve, active)
	return actions

static func get_field_spell_share_actions(session: SessionStateStoreScript.SessionData) -> Array:
	normalize_session(session)
	var actions := []
	if session == null:
		return actions
	var active := active_hero(session)
	if active.is_empty():
		return actions
	for reserve_value in field_rendezvous_heroes(session):
		if not (reserve_value is Dictionary):
			continue
		var reserve: Dictionary = reserve_value
		_append_field_spell_share_actions(actions, active, reserve)
		_append_field_spell_share_actions(actions, reserve, active)
	return actions

static func transfer_field_stack(
	session: SessionStateStoreScript.SessionData,
	source_hero_id: String,
	target_hero_id: String,
	unit_id: String,
	amount_token: String
) -> Dictionary:
	normalize_session(session)
	if session == null:
		return {"ok": false, "message": "No expedition is available for a field transfer."}
	if source_hero_id == "" or target_hero_id == "" or source_hero_id == target_hero_id:
		return {"ok": false, "message": "Choose two different controlled commanders."}
	var source := hero_by_id(session, source_hero_id)
	var target := hero_by_id(session, target_hero_id)
	if source.is_empty() or target.is_empty():
		return {"ok": false, "message": "Both commanders must remain under player control."}
	var active_id := String(session.overworld.get("active_hero_id", ""))
	if source_hero_id != active_id and target_hero_id != active_id:
		return {"ok": false, "message": "Field transfers must include the active commander."}
	if _normalize_position(source.get("position", {})) != _normalize_position(target.get("position", {})):
		return {"ok": false, "message": "The commanders must occupy the same field tile."}
	if unit_id == "":
		return {"ok": false, "message": "That transfer order is missing a unit id."}

	var source_stacks := _holder_stacks(session, {}, source_hero_id)
	var source_index := _stack_index_by_unit(source_stacks, unit_id)
	if source_index < 0:
		return {"ok": false, "message": "That stack is no longer available for transfer."}
	var source_stack: Dictionary = source_stacks[source_index]
	var available := int(source_stack.get("count", 0))
	var transfer_count := _resolve_transfer_amount(amount_token, available)
	if transfer_count <= 0:
		return {"ok": false, "message": "No troops are available for transfer."}

	var admission := army_addition_plan(_holder_stacks(session, {}, target_hero_id), {unit_id: transfer_count})
	if not bool(admission.get("ok", false)):
		return admission
	source_stack["count"] = available - transfer_count
	if int(source_stack.get("count", 0)) > 0:
		source_stacks[source_index] = source_stack
	else:
		source_stacks.remove_at(source_index)
	var target_stacks: Array = admission.get("stacks", [])

	_set_holder_stacks(session, {}, source_hero_id, source_stacks)
	_set_holder_stacks(session, {}, target_hero_id, target_stacks)
	var unit_name := String(ContentService.get_unit(unit_id).get("name", unit_id))
	return {
		"ok": true,
		"message": "Moved %d %s from %s to %s." % [
			transfer_count,
			unit_name,
			String(source.get("name", source_hero_id)),
			String(target.get("name", target_hero_id)),
		],
		"source_hero_id": source_hero_id,
		"target_hero_id": target_hero_id,
		"unit_id": unit_id,
		"transferred_count": transfer_count,
	}

static func transfer_field_artifact(
	session: SessionStateStoreScript.SessionData,
	source_hero_id: String,
	target_hero_id: String,
	artifact_id: String
) -> Dictionary:
	normalize_session(session)
	if session == null:
		return {"ok": false, "message": "No expedition is available for an artifact handoff."}
	if source_hero_id == "" or target_hero_id == "" or source_hero_id == target_hero_id:
		return {"ok": false, "message": "Choose two different controlled commanders."}
	var source := hero_by_id(session, source_hero_id)
	var target := hero_by_id(session, target_hero_id)
	if source.is_empty() or target.is_empty():
		return {"ok": false, "message": "Both commanders must remain under player control."}
	var active_id := String(session.overworld.get("active_hero_id", ""))
	if source_hero_id != active_id and target_hero_id != active_id:
		return {"ok": false, "message": "Field handoffs must include the active commander."}
	if _normalize_position(source.get("position", {})) != _normalize_position(target.get("position", {})):
		return {"ok": false, "message": "The commanders must occupy the same field tile."}
	if artifact_id == "" or ContentService.get_artifact(artifact_id).is_empty():
		return {"ok": false, "message": "That artifact handoff is invalid."}
	if not ArtifactRulesScript.has_artifact(source, artifact_id):
		return {"ok": false, "message": "That artifact is no longer owned by %s." % String(source.get("name", source_hero_id))}
	if ArtifactRulesScript.has_artifact(target, artifact_id):
		return {"ok": false, "message": "%s already owns %s." % [String(target.get("name", target_hero_id)), ArtifactRulesScript.artifact_name(artifact_id)]}

	var source_previous_max := movement_max_for_hero(source, session)
	var target_previous_max := movement_max_for_hero(target, session)
	var removal := ArtifactRulesScript.remove_owned_artifact(source, artifact_id)
	if not bool(removal.get("ok", false)):
		return {"ok": false, "message": String(removal.get("message", "Artifact handoff failed."))}
	var claim := ArtifactRulesScript.claim_artifact(target, artifact_id, "Received", true)
	if not bool(claim.get("ok", false)) or bool(claim.get("duplicate", false)):
		return {"ok": false, "message": String(claim.get("message", "Artifact handoff failed."))}
	var source_updated: Dictionary = removal.get("hero", source)
	var target_updated: Dictionary = claim.get("hero", target)
	source_updated = _preserve_movement_deficit_after_artifact_change(source_updated, source_previous_max, session)
	target_updated = _preserve_movement_deficit_after_artifact_change(target_updated, target_previous_max, session)
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	_replace_hero_in_array(heroes, source_updated)
	_replace_hero_in_array(heroes, target_updated)
	session.overworld["player_heroes"] = heroes
	_sync_active_hero_mirror(session)
	var target_location := ArtifactRulesScript.locate_artifact(target_updated, artifact_id)
	return {
		"ok": true,
		"message": "Passed %s from %s to %s. %s." % [
			ArtifactRulesScript.artifact_name(artifact_id),
			String(source.get("name", source_hero_id)),
			String(target.get("name", target_hero_id)),
			ArtifactRulesScript.artifact_collection_state(target_updated, artifact_id),
		],
		"source_hero_id": source_hero_id,
		"target_hero_id": target_hero_id,
		"artifact_id": artifact_id,
		"source_previous_location": String(removal.get("previous_location", "")),
		"source_previous_slot": String(removal.get("previous_slot", "")),
		"target_location": String(target_location.get("location", "")),
		"target_slot": String(target_location.get("slot", "")),
		"auto_equipped": bool(claim.get("auto_equipped", false)),
	}

static func teach_field_spell(
	session: SessionStateStoreScript.SessionData,
	source_hero_id: String,
	target_hero_id: String,
	spell_id: String
) -> Dictionary:
	normalize_session(session)
	if session == null:
		return {"ok": false, "message": "No expedition is available for spell teaching."}
	if source_hero_id == "" or target_hero_id == "" or source_hero_id == target_hero_id:
		return {"ok": false, "message": "Choose two different controlled commanders."}
	var source := hero_by_id(session, source_hero_id)
	var target := hero_by_id(session, target_hero_id)
	if source.is_empty() or target.is_empty():
		return {"ok": false, "message": "Both commanders must remain under player control."}
	var active_id := String(session.overworld.get("active_hero_id", ""))
	if source_hero_id != active_id and target_hero_id != active_id:
		return {"ok": false, "message": "Field teaching must include the active commander."}
	if _normalize_position(source.get("position", {})) != _normalize_position(target.get("position", {})):
		return {"ok": false, "message": "The commanders must occupy the same field tile."}
	var spell := ContentService.get_spell(spell_id)
	if spell_id == "" or spell.is_empty():
		return {"ok": false, "message": "That spell teaching order is invalid."}
	if not SpellRulesScript.knows_spell(source, spell_id):
		return {"ok": false, "message": "%s no longer knows %s." % [String(source.get("name", source_hero_id)), String(spell.get("name", spell_id))]}
	if SpellRulesScript.knows_spell(target, spell_id):
		return {"ok": false, "message": "%s already knows %s." % [String(target.get("name", target_hero_id)), String(spell.get("name", spell_id))]}

	var learning := SpellRulesScript.learn_spell(target, spell_id)
	if not bool(learning.get("ok", false)):
		return {"ok": false, "message": String(learning.get("message", "Spell teaching failed."))}
	var target_updated: Dictionary = learning.get("hero", target)
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	_replace_hero_in_array(heroes, target_updated)
	session.overworld["player_heroes"] = heroes
	_sync_active_hero_mirror(session)
	return {
		"ok": true,
		"message": "%s teaches %s to %s." % [
			String(source.get("name", source_hero_id)),
			String(spell.get("name", spell_id)),
			String(target.get("name", target_hero_id)),
		],
		"source_hero_id": source_hero_id,
		"target_hero_id": target_hero_id,
		"spell_id": spell_id,
	}

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

	var admission := army_addition_plan(_holder_stacks(session, town, target_holder), {unit_id: transfer_count})
	if not bool(admission.get("ok", false)):
		return admission
	source_stack["count"] = available - transfer_count
	if int(source_stack.get("count", 0)) > 0:
		source_stacks[source_index] = source_stack
	else:
		source_stacks.remove_at(source_index)

	var target_stacks: Array = admission.get("stacks", [])

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
	var scenario := ContentService.get_scenario_readonly(session.scenario_id)
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

static func closest_hero_target(session: SessionStateStoreScript.SessionData, origin: Vector2i = Vector2i.ZERO, level: int = 0) -> Dictionary:
	normalize_session(session)
	var best := {}
	for hero in session.overworld.get("player_heroes", []):
		if not (hero is Dictionary) or not OverworldLevelRulesScript.on_level(hero, level):
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
	if not best.is_empty() and level != 0:
		best["level"] = level
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
					"level": OverworldLevelRulesScript.level_of(hero),
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
	return OverworldLevelRulesScript.position(value)

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
			var normalized_stack := {"unit_id": unit_id, "count": count}
			var slot_index := int(stack.get(ARMY_SLOT_INDEX_KEY, -1))
			if slot_index >= 0 and slot_index < ARMY_SLOT_COUNT:
				normalized_stack[ARMY_SLOT_INDEX_KEY] = slot_index
			stacks.append(normalized_stack)
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
	return "%s | %s%s | %s" % [
		hero_identity_context_line(hero),
		", ".join(tags) + " | " if not tags.is_empty() else "",
		hero_progress_context_line(hero),
		hero_readiness_context_line(hero, true),
	]

static func _army_count_summary(army: Variant) -> Dictionary:
	var stacks = army.get("stacks", []) if army is Dictionary else []
	var troops := 0
	var groups := 0
	if stacks is Array:
		for stack in stacks:
			if not (stack is Dictionary):
				continue
			var count := int(stack.get("count", 0))
			if count <= 0:
				continue
			troops += count
			groups += 1
	return {"troops": troops, "groups": groups}

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
	return _normalize_position(hero.get("position", {})) == OverworldLevelRulesScript.town_entrance(town)

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
	if session == null:
		return
	if holder_id == HOLDER_GARRISON:
		if town.is_empty():
			return
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

static func _append_field_transfer_actions(actions: Array, source: Dictionary, target: Dictionary) -> void:
	var source_id := String(source.get("id", ""))
	var target_id := String(target.get("id", ""))
	if source_id == "" or target_id == "":
		return
	var source_name := String(source.get("name", source_id))
	var target_name := String(target.get("name", target_id))
	for stack_value in source.get("army", {}).get("stacks", []):
		if not (stack_value is Dictionary):
			continue
		var stack: Dictionary = stack_value
		var unit_id := String(stack.get("unit_id", ""))
		var count := int(stack.get("count", 0))
		if unit_id == "" or count <= 0:
			continue
		var unit_name := String(ContentService.get_unit(unit_id).get("name", unit_id))
		var seen_transfer_counts := {}
		var admission := army_addition_plan(target.get("army", {}).get("stacks", []), {unit_id: 1})
		for amount_token_value in _transfer_amount_tokens(count):
			var amount_token := String(amount_token_value)
			var transfer_count := _resolve_transfer_amount(amount_token, count)
			if seen_transfer_counts.has(transfer_count):
				continue
			seen_transfer_counts[transfer_count] = true
			actions.append({
				"id": "field_transfer:%s:%s:%s:%s" % [source_id, target_id, unit_id, amount_token],
				"label": "%s -> %s | %d %s" % [source_name, target_name, transfer_count, unit_name],
				"summary": "Move %s of %d %s from %s to %s; both commanders remain on this tile." % [
					_transfer_amount_label(amount_token, count),
					count,
					unit_name,
					source_name,
					target_name,
				],
				"source_hero_id": source_id,
				"target_hero_id": target_id,
				"unit_id": unit_id,
				"amount_token": amount_token,
				"transfer_count": transfer_count,
				"disabled": not bool(admission.get("ok", false)),
				"disabled_reason": String(admission.get("message", "")),
			})

static func _append_field_artifact_transfer_actions(actions: Array, source: Dictionary, target: Dictionary) -> void:
	var source_id := String(source.get("id", ""))
	var target_id := String(target.get("id", ""))
	if source_id == "" or target_id == "":
		return
	var source_name := String(source.get("name", source_id))
	var target_name := String(target.get("name", target_id))
	for artifact_id_value in ArtifactRulesScript.owned_artifact_ids(source):
		var artifact_id := String(artifact_id_value)
		if artifact_id == "" or ArtifactRulesScript.has_artifact(target, artifact_id):
			continue
		var source_location := ArtifactRulesScript.locate_artifact(source, artifact_id)
		actions.append({
			"id": "field_artifact_transfer:%s:%s:%s" % [source_id, target_id, artifact_id],
			"label": "%s -> %s | %s" % [source_name, target_name, ArtifactRulesScript.artifact_name(artifact_id)],
			"summary": "%s | From %s in %s | To %s: %s" % [
				ArtifactRulesScript.artifact_effect_summary(artifact_id),
				source_name,
				String(source_location.get("slot", "pack")).capitalize() if String(source_location.get("location", "")) == "equipped" else "pack",
				target_name,
				ArtifactRulesScript.artifact_collection_state(target, artifact_id),
			],
			"source_hero_id": source_id,
			"target_hero_id": target_id,
			"artifact_id": artifact_id,
			"kind": "artifact",
		})

static func _append_field_spell_share_actions(actions: Array, source: Dictionary, target: Dictionary) -> void:
	var source_id := String(source.get("id", ""))
	var target_id := String(target.get("id", ""))
	if source_id == "" or target_id == "":
		return
	var source_name := String(source.get("name", source_id))
	var target_name := String(target.get("name", target_id))
	for spell_value in SpellRulesScript.known_spells(source):
		if not (spell_value is Dictionary):
			continue
		var spell: Dictionary = spell_value
		var spell_id := String(spell.get("id", ""))
		if spell_id == "" or SpellRulesScript.knows_spell(target, spell_id):
			continue
		actions.append({
			"id": "field_spell_share:%s:%s:%s" % [source_id, target_id, spell_id],
			"label": "%s -> %s | Teach %s" % [source_name, target_name, String(spell.get("name", spell_id))],
			"summary": "Tier %d %s spell | %d mana to cast | %s keeps it; %s learns it." % [
				int(spell.get("tier", 1)),
				String(spell.get("context", "battle")).capitalize(),
				int(spell.get("mana_cost", 0)),
				source_name,
				target_name,
			],
			"source_hero_id": source_id,
			"target_hero_id": target_id,
			"spell_id": spell_id,
			"kind": "spell",
		})

static func _preserve_movement_deficit_after_artifact_change(
	hero: Dictionary,
	previous_max: int,
	session: SessionStateStoreScript.SessionData
) -> Dictionary:
	var updated := hero.duplicate(true)
	var movement: Dictionary = updated.get("movement", {}) if updated.get("movement", {}) is Dictionary else {}
	var new_max := movement_max_for_hero(updated, session)
	var current := int(movement.get("current", previous_max))
	movement["current"] = clamp(current + (new_max - previous_max), 0, new_max)
	movement["max"] = new_max
	updated["movement"] = movement
	return updated

static func _stack_index_by_unit(stacks: Array, unit_id: String) -> int:
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			return index
	return -1

static func _army_slot_holder_is_available(
	session: SessionStateStoreScript.SessionData,
	town: Dictionary,
	holder_id: String
) -> bool:
	if session == null or holder_id == "":
		return false
	if not town.is_empty():
		return holder_id in _stationed_holder_ids(session, town)
	return holder_id == String(session.overworld.get("active_hero_id", "")) and not hero_by_id(session, holder_id).is_empty()

static func _slotted_stacks(value: Variant) -> Array:
	var stacks := []
	var claimed := {}
	if value is Array:
		for stack_value in value:
			if not (stack_value is Dictionary):
				continue
			var stack: Dictionary = stack_value.duplicate(true)
			var unit_id := String(stack.get("unit_id", ""))
			var count := int(stack.get("count", 0))
			if unit_id == "" or count <= 0:
				continue
			var preferred_slot := int(stack.get(ARMY_SLOT_INDEX_KEY, -1))
			if preferred_slot < 0 or preferred_slot >= ARMY_SLOT_COUNT or claimed.has(preferred_slot):
				preferred_slot = _first_open_army_slot(claimed)
			if preferred_slot < 0:
				continue
			stack[ARMY_SLOT_INDEX_KEY] = preferred_slot
			claimed[preferred_slot] = true
			stacks.append(stack)
	stacks.sort_custom(_stack_slot_less)
	return stacks

static func _valid_stack_count(value: Variant) -> int:
	var count := 0
	if value is Array:
		for stack_value in value:
			if stack_value is Dictionary and String(stack_value.get("unit_id", "")) != "" and int(stack_value.get("count", 0)) > 0:
				count += 1
	return count

static func _first_open_army_slot(claimed: Dictionary) -> int:
	for slot_index in range(ARMY_SLOT_COUNT):
		if not claimed.has(slot_index):
			return slot_index
	return -1

static func _stack_slot_less(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get(ARMY_SLOT_INDEX_KEY, ARMY_SLOT_COUNT)) < int(right.get(ARMY_SLOT_INDEX_KEY, ARMY_SLOT_COUNT))

static func _stack_index_by_slot(stacks: Array, slot_index: int) -> int:
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and int(stack.get(ARMY_SLOT_INDEX_KEY, -1)) == slot_index:
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
	var keys := normalized.keys()
	keys.sort()
	for key in keys:
		var amount := int(normalized.get(key, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, key])
	return ", ".join(parts) if not parts.is_empty() else "free"
