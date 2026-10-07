extends Node

const REPORT_ID := "AI_HERO_TASK_LIVE_TURN_EXECUTION_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_report := _river_pass_live_heroes_take_player_sites()
	if case_report.is_empty():
		return
	var movement_case_report := _river_pass_heroes_spend_movement_points()
	if movement_case_report.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_enemy_turn_runs_ai_heroes",
		"behavior_policy": "run_enemy_turn_moves_ai_heroes_and_claims_sites_under_player_rules",
		"save_policy": "raid_hosts_from_old_saves_become_ai_heroes",
		"case": case_report,
		"movement_case": movement_case_report,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

## Two commanders' hosts from an older save stand on sites the human holds.
## They load as heroes and take both sites on the enemy turn.
func _river_pass_live_heroes_take_player_sites() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_player_position(session, {"x": 12, "y": 12})
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	_set_active_response(session, "river_free_company")
	# The pass's loose artifacts and caches are gone: the held sites are what
	# is left to take.
	_clear_loose_rewards(session)
	var free_company_before := _resource_controller(session, "river_free_company")
	var signal_post_before := _resource_controller(session, "river_signal_post")
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(_strong_raid_seed(session, config, "hero_vaska", "live_turn_vaska_free_company", {"x": 0, "y": 4}))
	encounters.append(_strong_raid_seed(session, config, "hero_sable", "live_turn_sable_signal_post", {"x": 2, "y": 3}))
	session.overworld["encounters"] = encounters
	_load_as_old_save(session)
	_assert_ai_hero(_encounter(session, "live_turn_vaska_free_company"), "Vaska")
	_assert_ai_hero(_encounter(session, "live_turn_sable_signal_post"), "Sable")
	if _failed:
		return {}
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var vaska_progress_before := _commander_progress_snapshot(session, "hero_vaska")
	var sable_progress_before := _commander_progress_snapshot(session, "hero_sable")

	var result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(result.get("ok", false)):
		_fail("Enemy turn failed: %s" % JSON.stringify(result))
		return {}
	var vaska := _encounter(session, "live_turn_vaska_free_company")
	var sable := _encounter(session, "live_turn_sable_signal_post")
	var free_company_after := _resource_controller(session, "river_free_company")
	var signal_post_after := _resource_controller(session, "river_signal_post")
	if free_company_after != MIRECLAW:
		_fail("Free Company was not taken by an enemy hero: before=%s after=%s events=%s vaska=%s" % [free_company_before, free_company_after, JSON.stringify(_event_types(result.get("events", []))), JSON.stringify(vaska)])
		return {}
	if signal_post_after != MIRECLAW:
		_fail("Signal Post was not taken by an enemy hero: before=%s after=%s events=%s sable=%s" % [signal_post_before, signal_post_after, JSON.stringify(result.get("events", [])).left(3000), JSON.stringify(sable.get("ai_hero", {}))])
		return {}
	var event_types := _event_types(result.get("events", []))
	_assert_event(result.get("events", []), "ai_site_seized", "river_free_company")
	_assert_event(result.get("events", []), "ai_site_seized", "river_signal_post")
	_assert_site_transition_event(result.get("events", []), "river_free_company", "player", MIRECLAW)
	_assert_site_transition_event(result.get("events", []), "river_signal_post", "player", MIRECLAW)
	_assert_site_route_closure_event(result.get("events", []), "river_free_company", true)
	_assert_site_route_closure_event(result.get("events", []), "river_signal_post", false)
	if _failed:
		return {}
	# Heroes keep their plans to themselves: no raid targets, no task board.
	for hero in [vaska, sable]:
		if String(hero.get("target_kind", "")) != "" or String(hero.get("target_placement_id", "")) != "":
			_fail("An enemy hero exposed a raid-style target: %s" % JSON.stringify(hero))
			return {}
	if _enemy_state(session).has("hero_task_state"):
		_fail("The live turn wrote a raid task board: %s" % JSON.stringify(_enemy_state(session).get("hero_task_state", {})))
		return {}
	var vaska_progress_after := _commander_progress_snapshot(session, "hero_vaska")
	var sable_progress_after := _commander_progress_snapshot(session, "hero_sable")
	_assert_progression(vaska_progress_before, vaska_progress_after, EnemyAdventureRules.COMMANDER_OUTCOME_RESOURCE_SECURED, "Vaska")
	_assert_progression(sable_progress_before, sable_progress_after, EnemyAdventureRules.COMMANDER_OUTCOME_RESOURCE_SECURED, "Sable")
	if _failed:
		return {}
	EnemyTurnRules.normalize_enemy_states(session)
	var vaska_progress_normalized := _commander_progress_snapshot(session, "hero_vaska")
	var sable_progress_normalized := _commander_progress_snapshot(session, "hero_sable")
	_assert_progression(vaska_progress_before, vaska_progress_normalized, EnemyAdventureRules.COMMANDER_OUTCOME_RESOURCE_SECURED, "normalized Vaska")
	_assert_progression(sable_progress_before, sable_progress_normalized, EnemyAdventureRules.COMMANDER_OUTCOME_RESOURCE_SECURED, "normalized Sable")
	if _failed:
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Live turn public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	return {
		"case_id": "river_pass_live_heroes_take_player_sites",
		"free_company_before": free_company_before,
		"free_company_after": free_company_after,
		"signal_post_before": signal_post_before,
		"signal_post_after": signal_post_after,
		"event_types": event_types,
		"vaska_progress_before": vaska_progress_before,
		"vaska_progress_after": vaska_progress_after,
		"vaska_progress_normalized": vaska_progress_normalized,
		"sable_progress_before": sable_progress_before,
		"sable_progress_after": sable_progress_after,
		"sable_progress_normalized": sable_progress_normalized,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

## Raid hosts crept one tile a day. A hero gets the human's daily movement
## points, spends one per step, and starts every day with a full budget.
func _river_pass_heroes_spend_movement_points() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_player_position(session, {"x": 12, "y": 12})
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(_strong_raid_seed(session, config, "hero_vaska", "movement_vaska", {"x": 7, "y": 3}))
	session.overworld["encounters"] = encounters
	_load_as_old_save(session)
	var hero := _encounter(session, "movement_vaska")
	_assert_ai_hero(hero, "Vaska")
	if _failed:
		return {}
	var expected_max := HeroCommandRules.movement_max_for_hero(hero.get("enemy_commander_state", {}).merged({"base_movement": int(ContentService.get_hero("hero_vaska").get("base_movement", 10))}), "normal")
	var start := Vector2i(int(hero.get("x", 0)), int(hero.get("y", 0)))
	var result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(result.get("ok", false)):
		_fail("Enemy turn failed: %s" % JSON.stringify(result))
		return {}
	hero = _encounter(session, "movement_vaska")
	var movement: Dictionary = hero.get("ai_hero", {}).get("movement", {})
	var moved := maxi(absi(int(hero.get("x", 0)) - start.x), absi(int(hero.get("y", 0)) - start.y))
	if int(movement.get("max", 0)) != expected_max or expected_max <= 1:
		_fail("Hero movement budget should match the human's rule (%d): %s" % [expected_max, JSON.stringify(movement)])
		return {}
	if int(movement.get("current", 0)) >= int(movement.get("max", 0)):
		_fail("The hero spent no movement on its turn: %s" % JSON.stringify(hero))
		return {}
	if moved <= 1:
		_fail("The hero moved %d tile(s); heroes walk as far as their movement points allow." % moved)
		return {}
	return {
		"case_id": "river_pass_heroes_spend_movement_points",
		"movement": movement,
		"tiles_moved": moved,
	}

func _clear_loose_rewards(session) -> void:
	for artifact in session.overworld.get("artifact_nodes", []):
		if artifact is Dictionary:
			artifact["collected"] = true
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary) or bool(node.get("collected", false)):
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		if not bool(site.get("persistent_control", false)):
			node["collected"] = true

func _load_as_old_save(session) -> void:
	session.overworld.erase("ai_heroes_version")
	EnemyTurnRules.normalize_enemy_states(session)

func _assert_ai_hero(entry: Dictionary, label: String) -> void:
	if not (entry.get("ai_hero", null) is Dictionary):
		_fail("%s's raid host did not load as an enemy hero: %s" % [label, JSON.stringify(entry)])

func _raid_seed(session, config: Dictionary, roster_hero_id: String, placement_id: String, origin: Dictionary) -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": int(origin.get("x", 0)),
		"y": int(origin.get("y", 0)),
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		roster_hero_id,
		MIRECLAW,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW)
	)
	return EnemyAdventureRules.ensure_raid_army(raid, session)

func _strong_raid_seed(session, config: Dictionary, roster_hero_id: String, placement_id: String, origin: Dictionary) -> Dictionary:
	var raid := _raid_seed(session, config, roster_hero_id, placement_id, origin)
	var army := {
		"id": String(raid.get("encounter_id", "encounter_mire_raid")),
		"name": "Live Turn Proof Host",
		"stacks": [
			{"unit_id": "unit_bog_brute", "count": 12},
			{"unit_id": "unit_mire_slinger", "count": 12},
		],
	}
	raid["enemy_army"] = army
	if raid.get("enemy_commander_state", {}) is Dictionary:
		raid["enemy_commander_state"] = EnemyAdventureRules.sync_commander_army_continuity(
			raid.get("enemy_commander_state", {}),
			army,
			String(raid.get("encounter_id", "encounter_mire_raid"))
		)
	return raid

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

func _set_resource_controller(session, placement_id: String, faction_id: String) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary):
			continue
		if String(node.get("placement_id", "")) != placement_id:
			continue
		node["collected"] = true
		node["collected_by_faction_id"] = faction_id
		node["collected_day"] = max(1, int(session.day))
		nodes[index] = node
		session.overworld["resource_nodes"] = nodes
		return
	_fail("Could not find resource placement %s" % placement_id)

func _set_active_response(session, placement_id: String) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary) or String(node.get("placement_id", "")) != placement_id:
			continue
		node["response_origin"] = "field"
		node["response_last_day"] = int(session.day)
		node["response_until_day"] = int(session.day) + 2
		node["response_commander_id"] = "hero_player"
		node["response_security_rating"] = 2
		nodes[index] = node
		session.overworld["resource_nodes"] = nodes
		return
	_fail("Could not activate response for %s" % placement_id)

func _set_player_position(session, position: Dictionary) -> void:
	session.overworld["hero_position"] = {"x": int(position.get("x", 0)), "y": int(position.get("y", 0))}
	for heroes_key in ["heroes", "player_heroes"]:
		var heroes: Array = session.overworld.get(heroes_key, []) if session.overworld.get(heroes_key, []) is Array else []
		for index in range(heroes.size()):
			var hero = heroes[index]
			if hero is Dictionary and String(hero.get("owner", "player")) == "player":
				hero["x"] = int(position.get("x", 0))
				hero["y"] = int(position.get("y", 0))
				hero["position"] = session.overworld["hero_position"].duplicate(true)
				heroes[index] = hero
				session.overworld[heroes_key] = heroes

func _resource_controller(session, placement_id: String) -> String:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return String(node.get("collected_by_faction_id", ""))
	return ""

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _commander_progress_snapshot(session, roster_hero_id: String) -> Dictionary:
	var state := _enemy_state(session)
	for entry in state.get("commander_roster", []):
		if not (entry is Dictionary) or String(entry.get("roster_hero_id", "")) != roster_hero_id:
			continue
		var commander_state: Dictionary = entry.get("commander_state", {}) if entry.get("commander_state", {}) is Dictionary else {}
		return {
			"roster_hero_id": roster_hero_id,
			"experience": max(0, int(commander_state.get("experience", entry.get("experience", 0)))),
			"level": max(1, int(commander_state.get("level", entry.get("level", 1)))),
			"strategic_successes": max(0, int(commander_state.get("strategic_successes", entry.get("strategic_successes", 0)))),
			"last_outcome": String(commander_state.get("last_outcome", entry.get("last_outcome", ""))),
		}
	_fail("Could not find commander progress for %s" % roster_hero_id)
	return {}

func _assert_event(events: Variant, event_type: String, target_id: String) -> void:
	if not (events is Array):
		_fail("Events payload is not an array for %s/%s" % [event_type, target_id])
		return
	for event in events:
		if event is Dictionary and String(event.get("event_type", "")) == event_type and String(event.get("target_id", "")) == target_id:
			return
	_fail("Missing event %s for %s in %s" % [event_type, target_id, JSON.stringify(events)])

func _assert_site_transition_event(events: Variant, target_id: String, expected_before: String, expected_after: String) -> void:
	if not (events is Array):
		_fail("Events payload is not an array for site transition %s" % target_id)
		return
	for event in events:
		if not (event is Dictionary):
			continue
		if String(event.get("event_type", "")) != "ai_site_seized" or String(event.get("target_id", "")) != target_id:
			continue
		if String(event.get("target_controller_before", "")) != expected_before or String(event.get("target_controller_after", "")) != expected_after:
			_fail("Site transition event %s expected %s->%s, got %s" % [target_id, expected_before, expected_after, JSON.stringify(event)])
		return
	_fail("Missing site transition event for %s in %s" % [target_id, JSON.stringify(events)])

func _assert_site_route_closure_event(events: Variant, target_id: String, expected_closed: bool) -> void:
	if not (events is Array):
		_fail("Events payload is not an array for route closure %s" % target_id)
		return
	for event in events:
		if not (event is Dictionary):
			continue
		if String(event.get("event_type", "")) != "ai_site_seized" or String(event.get("target_id", "")) != target_id:
			continue
		var reason_codes: Array = event.get("reason_codes", []) if event.get("reason_codes", []) is Array else []
		if ("route_closed" in reason_codes) != expected_closed:
			_fail("Site route-closure event %s expected closed=%s, got %s" % [target_id, expected_closed, JSON.stringify(event)])
		return
	_fail("Missing site route-closure event for %s in %s" % [target_id, JSON.stringify(events)])

## Claiming a site counts as a strategic success. Experience comes from battles
## and from what the site grants, as for the human, not from the errand.
func _assert_progression(before: Dictionary, after: Dictionary, expected_outcome: String, label: String) -> void:
	if after.is_empty():
		_fail("%s commander progression snapshot is empty." % label)
		return
	if int(after.get("strategic_successes", 0)) <= int(before.get("strategic_successes", 0)):
		_fail("%s did not record a strategic_successes increment: before=%s after=%s" % [label, JSON.stringify(before), JSON.stringify(after)])
		return
	if String(after.get("last_outcome", "")) != expected_outcome:
		_fail("%s last_outcome expected %s, got %s" % [label, expected_outcome, JSON.stringify(after)])

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

func _public_event_leaks(public_events: Variant) -> bool:
	if not (public_events is Array):
		_fail("Public events are not an array.")
		return true
	var forbidden_tokens := ["resource_score_breakdown", "target_debug_reason", "final_priority", "hero_task_state", "task_id", "reservation_key"]
	var encoded := JSON.stringify(public_events)
	for token in forbidden_tokens:
		if token in encoded:
			_fail("Public event leaked internal live-turn token %s: %s" % [token, encoded])
			return true
	return false

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
