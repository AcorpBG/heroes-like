extends Node

const AiHeroRulesScript = preload("res://scripts/core/AiHeroRules.gd")

const REPORT_ID := "AI_RAID_ASSAULT_GROUPING_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"
const TOWN_ID := "duskfen_bastion"
const POST_MOVE_SUPPORT_TILE := Vector2i(4, 4)

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var commanderless_case_report := _river_pass_nearby_raids_group_for_town_assault()
	if commanderless_case_report.is_empty():
		return
	var commander_case_report := _river_pass_commander_raids_group_for_town_assault()
	if commander_case_report.is_empty():
		return
	var post_move_case_report := _river_pass_raids_group_after_leader_movement_for_town_assault()
	if post_move_case_report.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_ai_hero_assault_grouping_no_save_migration",
		"behavior_policy": "a_column_beside_a_hero_joins_it_and_lesser_heroes_hand_troops_to_the_main_hero_before_or_after_walking",
		"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
		"case": commanderless_case_report,
		"commander_case": commander_case_report,
		"post_move_case": post_move_case_report,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _river_pass_nearby_raids_group_for_town_assault() -> Dictionary:
	var session = _base_session()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_player_captured_retake_front(session, TOWN_ID)
	var config := _enemy_config()
	var leader := _raid_seed("grouping_assault_vaska", 7, 2, 7, true, session, config)
	var support := _raid_seed("grouping_support_column", 7, 3, 3, false, session, config)
	var leader_strength_before := EnemyAdventureRules.raid_strength(leader)
	var support_strength_before := EnemyAdventureRules.raid_strength(support)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(leader)
	encounters.append(support)
	session.overworld["encounters"] = encounters

	var active_before := _active_raid_count(session)
	var result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(result.get("ok", false)):
		_fail("Enemy turn failed during grouping fixture: %s" % JSON.stringify(result))
		return {}
	var after_leader := _encounter(session, "grouping_assault_vaska")
	if after_leader.is_empty():
		_fail("Leader raid disappeared after grouping fixture.")
		return {}
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	if "grouping_support_column" not in resolved:
		_fail("Support raid was not removed from active pressure after grouping: %s" % JSON.stringify(resolved))
		return {}
	# Old saves: the commanded host loads as a hero and the column standing
	# beside it joins that hero instead of marching on its own.
	if not AiHeroRulesScript.is_ai_hero(after_leader):
		_fail("Leader host did not load as an enemy hero: %s" % JSON.stringify(after_leader))
		return {}
	var leader_strength_after := EnemyAdventureRules.raid_strength(after_leader)
	if leader_strength_after < leader_strength_before + support_strength_before:
		_fail("Leader did not absorb support strength: before %d support %d after %d" % [leader_strength_before, support_strength_before, leader_strength_after])
		return {}
	var continuity: Dictionary = EnemyAdventureRules.commander_army_continuity(after_leader.get("enemy_commander_state", {}))
	if int(continuity.get("current_strength", 0)) != leader_strength_after:
		_fail("Leader commander continuity did not refresh after grouping: %s strength %d" % [JSON.stringify(continuity), leader_strength_after])
		return {}
	if String(after_leader.get("joined_column_placement_id", "")) != "grouping_support_column":
		_fail("Leader did not record the column that joined it: %s" % JSON.stringify(after_leader))
		return {}
	var event_types := _event_types(result.get("events", []))
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Grouping public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	if session.battle.is_empty():
		_fail("Grouped assault did not continue into a town-defense battle: %s" % JSON.stringify(after_leader))
		return {}
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	if String(battle_context.get("type", "")) != "town_defense" or String(battle_context.get("town_placement_id", "")) != TOWN_ID:
		_fail("Grouped assault queued wrong battle context: %s" % JSON.stringify(battle_context))
		return {}
	return {
		"case_id": "river_pass_nearby_raids_group_for_town_assault",
		"leader_id": "grouping_assault_vaska",
		"support_id": "grouping_support_column",
		"target_id": TOWN_ID,
		"active_before": active_before,
		"active_after": _active_raid_count(session),
		"leader_strength_before": leader_strength_before,
		"support_strength_before": support_strength_before,
		"leader_strength_after": leader_strength_after,
		"joined_column_id": String(after_leader.get("joined_column_placement_id", "")),
		"battle_context_type": String(battle_context.get("type", "")),
		"battle_town_id": String(battle_context.get("town_placement_id", "")),
		"event_types": event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _river_pass_commander_raids_group_for_town_assault() -> Dictionary:
	var session = _base_session()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_player_captured_retake_front(session, TOWN_ID)
	var config := _enemy_config()
	var leader := _raid_seed("grouping_commander_leader_vaska", 7, 2, 8, true, session, config, "hero_vaska")
	var support := _raid_seed("grouping_commander_support_sable", 7, 3, 4, true, session, config, "hero_sable")
	_garrison_between(session, support, leader)
	var leader_strength_before := EnemyAdventureRules.raid_strength(leader)
	var support_strength_before := EnemyAdventureRules.raid_strength(support)
	var leader_count_before := _creature_count(leader)
	var support_count_before := _creature_count(support)
	# An old save's task board must not keep driving the heroes.
	_seed_active_town_task(session, "hero_sable", "grouping_commander_support_sable")
	# Loose pickups would rightly draw the lesser hero away first.
	_clear_loose_rewards(session)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(leader)
	encounters.append(support)
	session.overworld["encounters"] = encounters

	var active_before := _active_raid_count(session)
	var result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(result.get("ok", false)):
		_fail("Enemy turn failed during commander grouping fixture: %s" % JSON.stringify(result))
		return {}
	var after_leader := _encounter(session, "grouping_commander_leader_vaska")
	if after_leader.is_empty():
		_fail("Commander leader raid disappeared after grouping fixture.")
		return {}
	var after_support := _encounter(session, "grouping_commander_support_sable")
	var handover := _assert_handover(session, after_leader, after_support, leader_count_before, support_count_before, "Commander", result)
	if handover.is_empty():
		return {}
	var leader_strength_after := EnemyAdventureRules.raid_strength(after_leader)
	var sable_continuity: Dictionary = EnemyAdventureRules.commander_army_continuity(after_support.get("enemy_commander_state", {}))
	var event_types := _event_types(result.get("events", []))
	if "ai_heroes_met" not in event_types:
		_fail("Commander grouping fixture did not record the troop handover: %s" % JSON.stringify(result))
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Commander grouping public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	return {
		"case_id": "river_pass_commander_raids_group_for_town_assault",
		"leader_id": "grouping_commander_leader_vaska",
		"support_id": "grouping_commander_support_sable",
		"target_id": TOWN_ID,
		"active_before": active_before,
		"active_after": _active_raid_count(session),
		"leader_strength_before": leader_strength_before,
		"support_strength_before": support_strength_before,
		"leader_strength_after": leader_strength_after,
		"leader_creatures_before": leader_count_before,
		"support_creatures_before": support_count_before,
		"leader_creatures_after": int(handover.get("leader_after", 0)),
		"support_creatures_after": int(handover.get("support_after", 0)),
		"support_hero_current_strength": int(sable_continuity.get("current_strength", 0)),
		"event_types": event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _river_pass_raids_group_after_leader_movement_for_town_assault() -> Dictionary:
	var session = _base_session()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_player_captured_retake_front(session, TOWN_ID)
	var config := _enemy_config()
	var leader := _raid_seed("post_move_grouping_assault_vaska", 6, 2, 7, true, session, config)
	var support := _raid_seed("post_move_grouping_support_column", POST_MOVE_SUPPORT_TILE.x, POST_MOVE_SUPPORT_TILE.y, 3, true, session, config, "hero_sable")
	_garrison_between(session, support, leader)
	if maxi(absi(int(leader.x) - int(support.x)), absi(int(leader.y) - int(support.y))) <= 1:
		_fail("Post-move grouping fixture started with adjacent support; it should require movement first.")
		return {}
	var leader_strength_before := EnemyAdventureRules.raid_strength(leader)
	var support_strength_before := EnemyAdventureRules.raid_strength(support)
	var leader_count_before := _creature_count(leader)
	var support_count_before := _creature_count(support)
	_clear_loose_rewards(session)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(leader)
	encounters.append(support)
	session.overworld["encounters"] = encounters

	var active_before := _active_raid_count(session)
	var result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(result.get("ok", false)):
		_fail("Enemy turn failed during post-move grouping fixture: %s" % JSON.stringify(result))
		return {}
	var after_leader := _encounter(session, "post_move_grouping_assault_vaska")
	if after_leader.is_empty():
		_fail("Post-move grouping leader disappeared after enemy turn.")
		return {}
	var after_support := _encounter(session, "post_move_grouping_support_column")
	var handover := _assert_handover(session, after_leader, after_support, leader_count_before, support_count_before, "Post-move", result)
	if handover.is_empty():
		return {}
	var leader_strength_after := EnemyAdventureRules.raid_strength(after_leader)
	if int(after_support.get("x", 0)) == POST_MOVE_SUPPORT_TILE.x and int(after_support.get("y", 0)) == POST_MOVE_SUPPORT_TILE.y:
		_fail("Post-move support hero handed troops over without walking to the leader: %s" % JSON.stringify(after_support))
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_heroes_met" not in event_types:
		_fail("Post-move grouping fixture did not record the troop handover: %s" % JSON.stringify(result))
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Post-move grouping public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	if session.battle.is_empty():
		_fail("Post-move grouped assault did not continue into a town-defense battle: %s" % JSON.stringify(after_leader))
		return {}
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	if String(battle_context.get("type", "")) != "town_defense" or String(battle_context.get("town_placement_id", "")) != TOWN_ID:
		_fail("Post-move grouped assault queued wrong battle context: %s" % JSON.stringify(battle_context))
		return {}
	return {
		"case_id": "river_pass_raids_group_after_leader_movement_for_town_assault",
		"leader_id": "post_move_grouping_assault_vaska",
		"support_id": "post_move_grouping_support_column",
		"target_id": TOWN_ID,
		"active_before": active_before,
		"active_after": _active_raid_count(session),
		"leader_position_after": {"x": int(after_leader.get("x", 0)), "y": int(after_leader.get("y", 0))},
		"support_position_after": {"x": int(after_support.get("x", 0)), "y": int(after_support.get("y", 0))},
		"leader_strength_before": leader_strength_before,
		"support_strength_before": support_strength_before,
		"leader_strength_after": leader_strength_after,
		"leader_creatures_after": int(handover.get("leader_after", 0)),
		"support_creatures_after": int(handover.get("support_after", 0)),
		"battle_context_type": String(battle_context.get("type", "")),
		"battle_town_id": String(battle_context.get("town_placement_id", "")),
		"event_types": event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _raid_seed(placement_id: String, x: int, y: int, brute_count: int, with_commander: bool, session, config: Dictionary, roster_hero_id: String = "hero_vaska") -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": MIRECLAW,
		"commanderless_support_column": not with_commander,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"enemy_army": {
			"id": "%s_host" % placement_id,
			"name": "Assault Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": brute_count}],
		},
	}
	if with_commander:
		raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
			raid,
			roster_hero_id,
			MIRECLAW,
			session,
			{},
			EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW)
		)
	# A raid host in an older save marched on the retake town.
	raid.merge({"target_kind": "town", "target_placement_id": TOWN_ID, "target_label": "Duskfen Bastion"}, true)
	return EnemyAdventureRules.ensure_raid_army(raid, session) if with_commander else raid

func _base_session():
	var session = ScenarioFactory.create_session(
		RIVER_PASS,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	return session

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(RIVER_PASS)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == MIRECLAW:
			return config
	_fail("Could not find enemy config for %s" % MIRECLAW)
	return {}

func _enemy_state(session) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == MIRECLAW:
			return state
	_fail("Could not find enemy state for %s" % MIRECLAW)
	return {}

func _update_enemy_state(session, replacement: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if state is Dictionary and String(state.get("faction_id", "")) == String(replacement.get("faction_id", "")):
			states[index] = replacement
			session.overworld["enemy_states"] = states
			return
	_fail("Could not update enemy state for %s" % String(replacement.get("faction_id", "")))

func _seed_active_town_task(session, actor_id: String, origin_id: String) -> void:
	var state := _enemy_state(session)
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 4,
		"tasks": [
			{
				"task_id": "task:commander_grouping:%s:%s" % [actor_id, TOWN_ID],
				"owner_faction_id": MIRECLAW,
				"actor_kind": "commander_roster",
				"actor_id": actor_id,
				"source_kind": "saved_task_state",
				"source_id": origin_id,
				"task_class": "raid_town",
				"task_status": "active",
				"target_kind": "town",
				"target_id": TOWN_ID,
				"front_id": "town:%s" % TOWN_ID,
				"origin_kind": "encounter",
				"origin_id": origin_id,
				"priority_reason_codes": ["retake_front", "town_siege"],
				"assigned_day": int(session.day),
				"expires_day": int(session.day) + 7,
				"continuity_policy": "persist_until_invalid",
				"route_policy": "derive_route_on_turn",
				"last_validation": "valid",
				"reservation": {
					"reservation_status": "none",
					"reservation_scope": "none",
					"reservation_key": "",
				},
			}
		],
	}
	_update_enemy_state(session, state)

func _set_player_captured_retake_front(session, placement_id: String) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		town["owner"] = "player"
		town["front"] = {
			"state": "retake",
			"faction_id": MIRECLAW,
			"last_change_day": int(session.day),
			"stabilize_until_day": 0,
			"last_owner": "enemy",
			"capture_count": 1,
			"source": "test_fixture",
		}
		towns[index] = town
		session.overworld["towns"] = towns
		return
	_fail("Could not find town %s for retake-front fixture." % placement_id)

## Garrisons the support hero cannot take alone but the grouped army can, in
## every town the human holds:
## since the 2026-10-08 battle stat scaling a hero's damage spells count in its
## strength, and the town's starting garrison no longer stops four creatures
## led by a caster.
func _garrison_between(session, support: Dictionary, leader: Dictionary) -> void:
	var support_power := AiHeroRulesScript.hero_power(support)
	var grouped_stacks: Array = leader.get("enemy_army", {}).get("stacks", []).duplicate(true)
	grouped_stacks.append({"unit_id": "unit_bog_brute", "count": _creature_count(support) - 1})
	var grouped_power := AiHeroRulesScript.army_power(grouped_stacks, leader.get("enemy_commander_state", {}))
	var target := (support_power + grouped_power) * 0.5 / AiHeroRulesScript.TOWN_ATTACK_RATIO
	var guard_power := AiHeroRulesScript.army_power([{"unit_id": "unit_river_guard", "count": 1}])
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if towns[index] is Dictionary and String(towns[index].get("owner", "")) == "player":
			towns[index]["garrison"] = [{"unit_id": "unit_river_guard", "count": maxi(1, int(round(target / guard_power)))}]
	session.overworld["towns"] = towns

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _active_raid_count(session) -> int:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	var count := 0
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != MIRECLAW:
			continue
		if String(encounter.get("placement_id", "")) in resolved:
			continue
		count += 1
	return count

func _event_types(events: Variant) -> Array:
	var types := []
	if not (events is Array):
		return types
	for event in events:
		if event is Dictionary:
			var event_type := String(event.get("event_type", ""))
			if event_type != "" and event_type not in types:
				types.append(event_type)
	types.sort()
	return types

## An empty field: no pickups and no sites, so the heroes' only errands are
## the assault and getting ready for it.
func _clear_loose_rewards(session) -> void:
	for artifact in session.overworld.get("artifact_nodes", []):
		if artifact is Dictionary:
			artifact["collected"] = true
	session.overworld["resource_nodes"] = []

func _event_lines(result: Dictionary) -> Array:
	var lines := []
	for event in result.get("events", []):
		if event is Dictionary:
			lines.append("%s|%s|%s" % [String(event.get("event_type", "")), String(event.get("actor_id", "")), String(event.get("target_id", ""))])
	return lines

func _creature_count(entry: Dictionary) -> int:
	var count := 0
	var army = entry.get("enemy_army", {})
	if army is Dictionary:
		for stack in army.get("stacks", []):
			if stack is Dictionary:
				count += int(stack.get("count", 0))
	return count

## Both hosts load as heroes; the lesser one keeps a single creature and the
## main hero carries everything else into the assault.
func _assert_handover(session, after_leader: Dictionary, after_support: Dictionary, leader_before: int, support_before: int, label: String, result: Dictionary) -> Dictionary:
	if not AiHeroRulesScript.is_ai_hero(after_leader) or not AiHeroRulesScript.is_ai_hero(after_support):
		_fail("%s hosts did not load as enemy heroes: %s" % [label, JSON.stringify([after_leader, after_support])])
		return {}
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	if String(after_support.get("placement_id", "")) in resolved:
		_fail("%s support hero left the map after handing over troops." % label)
		return {}
	var leader_after := _creature_count(after_leader)
	var support_after := _creature_count(after_support)
	# The lesser hero keeps one creature (it may muster more afterwards).
	if support_after < 1 or leader_after != leader_before + support_before - 1:
		_fail("%s support hero did not hand its troops to the leader: leader %d -> %d, support %d -> %d; events %s" % [label, leader_before, leader_after, support_before, support_after, JSON.stringify(_event_lines(result))])
		return {}
	var continuity: Dictionary = EnemyAdventureRules.commander_army_continuity(after_leader.get("enemy_commander_state", {}))
	if int(continuity.get("current_strength", 0)) != EnemyAdventureRules.raid_strength(after_leader):
		_fail("%s leader continuity did not refresh after the handover: %s" % [label, JSON.stringify(continuity)])
		return {}
	return {"leader_after": leader_after, "support_after": support_after}

func _public_event_leaks(public_events: Variant) -> bool:
	var forbidden_tokens := ["target_debug_reason", "hero_task_state", "task_id", "reservation_key", "garrison_score", "raid_score", "grouped_into"]
	var encoded := JSON.stringify(public_events)
	for token in forbidden_tokens:
		if encoded.find(token) >= 0:
			_fail("Grouping public events leaked internal token %s" % token)
			return true
	return false

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
