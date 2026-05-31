extends Node

const REPORT_ID := "AI_NEUTRAL_TOWN_EXPANSION_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"
const NEUTRAL_TOWN_ID := "mireford_neutral_hold"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var plan_case := _neutral_town_is_planned_expansion_target()
	if plan_case.is_empty():
		return
	var capture_case := _arrived_raid_captures_empty_neutral_town()
	if capture_case.is_empty():
		return
	var post_capture_support_case := _duplicate_assault_reinforces_newly_captured_town()
	if post_capture_support_case.is_empty():
		return
	var defender_rotation_case := _stronger_support_rotates_town_defender_without_duplication()
	if defender_rotation_case.is_empty():
		return
	var defended_plan_case := _defended_neutral_town_is_planned_assault_target()
	if defended_plan_case.is_empty():
		return
	var defended_risk_case := _weak_raid_delays_defended_neutral_town_assault()
	if defended_risk_case.is_empty():
		return
	var defended_capture_case := _ready_raid_captures_defended_neutral_town_after_battle()
	if defended_capture_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_neutral_town_expansion_and_assault_no_save_migration",
		"behavior_policy": "ai_commanders_plan_capture_assault_and_post_capture_support_neutral_towns",
		"plan_case": plan_case,
		"capture_case": capture_case,
		"post_capture_support_case": post_capture_support_case,
		"defender_rotation_case": defender_rotation_case,
		"defended_plan_case": defended_plan_case,
		"defended_risk_case": defended_risk_case,
		"defended_capture_case": defended_capture_case,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _neutral_town_is_planned_expansion_target() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	_prepare_neutral_town_only_front(session)
	var result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	var task := _task_for_target(session, "town", NEUTRAL_TOWN_ID)
	if task.is_empty():
		_fail("Planner did not create a neutral-town expansion task: %s" % JSON.stringify(result))
		return {}
	var reason_codes := _string_array(task.get("priority_reason_codes", []))
	if "town_expansion" not in reason_codes or "neutral_town_claim" not in reason_codes:
		_fail("Neutral-town expansion task missed reason codes: %s" % JSON.stringify(task))
		return {}
	if String(task.get("task_status", "")) != "planned":
		_fail("Neutral-town expansion task should be planned: %s" % JSON.stringify(task))
		return {}
	return {
		"case_id": "neutral_town_is_planned_expansion_target",
		"planned_count": int(result.get("planned_count", 0)),
		"task_id": String(task.get("task_id", "")),
		"task_status": String(task.get("task_status", "")),
		"target_kind": String(task.get("target_kind", "")),
		"target_id": String(task.get("target_id", "")),
		"reason_codes": reason_codes,
	}

func _arrived_raid_captures_empty_neutral_town() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	_prepare_neutral_town_only_front(session)
	_seed_task_board(session, [_town_expansion_task("hero_vaska", NEUTRAL_TOWN_ID, "active", "valid")])
	var raid := _neutral_town_raid(session)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters
	var pressure_before := int(state.get("pressure", 0))

	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var town := _town(session, NEUTRAL_TOWN_ID)
	if String(town.get("owner", "neutral")) != "enemy":
		_fail("Neutral town was not captured by AI: %s" % JSON.stringify(town))
		return {}
	if String(town.get("controlling_faction_id", "")) != MIRECLAW:
		_fail("Captured neutral town did not record controlling faction: %s" % JSON.stringify(town))
		return {}
	var front: Dictionary = town.get("front", {}) if town.get("front", {}) is Dictionary else {}
	if String(front.get("state", "")) != "stabilizing" or String(front.get("faction_id", "")) != MIRECLAW:
		_fail("Captured neutral town did not enter enemy stabilization front state: %s" % JSON.stringify(front))
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_town_captured" not in event_types:
		_fail("Neutral town capture did not emit ai_town_captured: %s" % JSON.stringify(result))
		return {}
	var after_raid := _encounter(session, "neutral_town_vaska")
	if after_raid.is_empty():
		_fail("Neutral-town raid disappeared after capture.")
		return {}
	if _army_strength(town.get("garrison", [])) <= 0:
		_fail("Captured neutral town did not receive the capturing host as garrison: %s" % JSON.stringify(town))
		return {}
	if String(town.get("ai_defended_by_faction_id", "")) != MIRECLAW or String(town.get("ai_defender_roster_hero_id", "")) != "hero_vaska":
		_fail("Captured neutral town did not station the capturing commander as defender: %s" % JSON.stringify(town))
		return {}
	if not _resolved_has(session, "neutral_town_vaska"):
		_fail("Captured neutral-town field raid was not retired/resolved.")
		return {}
	if _army_strength(after_raid.get("enemy_army", {}).get("stacks", [])) > 0:
		_fail("Captured neutral-town raid kept field army after garrison transfer: %s" % JSON.stringify(after_raid))
		return {}
	var commander_state: Dictionary = after_raid.get("enemy_commander_state", {}) if after_raid.get("enemy_commander_state", {}) is Dictionary else {}
	if String(commander_state.get("last_outcome", "")) != "town_captured":
		_fail("Neutral-town commander did not record town_captured outcome: %s" % JSON.stringify(commander_state))
		return {}
	var roster_entry := _commander_roster_entry(session, "hero_vaska")
	if String(roster_entry.get("status", "")) != EnemyAdventureRules.COMMANDER_STATUS_ACTIVE or String(roster_entry.get("active_placement_id", "")) != "town_defense:%s" % NEUTRAL_TOWN_ID:
		_fail("Neutral-town capture did not leave commander stationed on town defense: %s" % JSON.stringify(roster_entry))
		return {}
	_assert_task_status(session, "hero_vaska", "town", NEUTRAL_TOWN_ID, "completed", "valid")
	if _failed:
		return {}
	return {
		"case_id": "arrived_raid_captures_empty_neutral_town",
		"owner_after": String(town.get("owner", "")),
		"controlling_faction_id": String(town.get("controlling_faction_id", "")),
		"front_state": String(front.get("state", "")),
		"event_types": event_types,
		"pressure_before": pressure_before,
		"pressure_after": int(result.get("state", state).get("pressure", 0)),
		"commander_last_outcome": String(commander_state.get("last_outcome", "")),
		"garrison_strength_after": _army_strength(town.get("garrison", [])),
		"field_raid_resolved": _resolved_has(session, "neutral_town_vaska"),
		"stationed_commander_status": String(roster_entry.get("status", "")),
	}

func _duplicate_assault_reinforces_newly_captured_town() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	_prepare_neutral_town_only_front(session)
	_seed_task_board(session, [
		_town_expansion_task("hero_vaska", NEUTRAL_TOWN_ID, "active", "valid"),
		_town_expansion_task("hero_sable", NEUTRAL_TOWN_ID, "active", "valid"),
	])
	var capture_raid := _neutral_town_raid(session)
	var support_raid := _neutral_town_support_raid(session)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(capture_raid)
	encounters.append(support_raid)
	session.overworld["encounters"] = encounters

	var capture_result := EnemyAdventureRules.advance_raids(
		session,
		config,
		MIRECLAW,
		state,
		{"only_placement_ids": ["neutral_town_vaska"]}
	)
	state = capture_result.get("state", state)
	var captured_town := _town(session, NEUTRAL_TOWN_ID)
	if String(captured_town.get("owner", "neutral")) != "enemy":
		_fail("Post-capture support fixture failed to capture neutral town first: %s" % JSON.stringify(captured_town))
		return {}
	var garrison_before := _army_strength(captured_town.get("garrison", []))
	var support_before := _encounter(session, "neutral_town_sable_support")
	if support_before.is_empty():
		_fail("Post-capture support raid disappeared before continuation.")
		return {}
	var support_strength := EnemyAdventureRules.raid_strength(support_before)

	var support_result := EnemyAdventureRules.advance_raids(
		session,
		config,
		MIRECLAW,
		state,
		{"only_placement_ids": ["neutral_town_sable_support"]}
	)
	var defended_town := _town(session, NEUTRAL_TOWN_ID)
	var garrison_after := _army_strength(defended_town.get("garrison", []))
	if garrison_after <= garrison_before:
		_fail("Post-capture support did not reinforce captured town: before=%d after=%d result=%s" % [garrison_before, garrison_after, JSON.stringify(support_result)])
		return {}
	if not _resolved_has(session, "neutral_town_sable_support"):
		_fail("Post-capture support field raid did not resolve into town defense.")
		return {}
	if String(defended_town.get("ai_defender_roster_hero_id", "")) != "hero_vaska":
		_fail("Weaker post-capture support stole the existing town defender slot: %s" % JSON.stringify(defended_town))
		return {}
	var after_support := _encounter(session, "neutral_town_sable_support")
	var support_army_strength_after := _army_strength(after_support.get("enemy_army", {}).get("stacks", []))
	if support_army_strength_after > 0:
		_fail("Post-capture support kept a field army after reinforcing town: %s" % JSON.stringify(after_support))
		return {}
	var event_types := _event_types(support_result.get("events", []))
	if "ai_town_defended" not in event_types:
		_fail("Post-capture support did not emit a town defense event: %s" % JSON.stringify(support_result))
		return {}
	var reason_codes := _event_reason_codes(support_result.get("events", []), "ai_town_defended")
	if "post_capture_support" not in reason_codes or "town_defense" not in reason_codes:
		_fail("Post-capture support defense missed reason codes: %s" % JSON.stringify(support_result))
		return {}
	var message := String(support_result.get("message", ""))
	if "pillages" in message or " press " in message:
		_fail("Post-capture stationed support still produced field pressure text: %s" % message)
		return {}
	var defender_roster_entry := _commander_roster_entry(session, "hero_vaska")
	if String(defender_roster_entry.get("status", "")) != EnemyAdventureRules.COMMANDER_STATUS_ACTIVE or String(defender_roster_entry.get("active_placement_id", "")) != "town_defense:%s" % NEUTRAL_TOWN_ID:
		_fail("Original town defender was not kept stationed after weaker support arrived: %s" % JSON.stringify(defender_roster_entry))
		return {}
	var support_roster_entry := _commander_roster_entry(session, "hero_sable")
	if String(support_roster_entry.get("status", "")) != EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE:
		_fail("Post-capture support commander was not released after folding into the town defense: %s" % JSON.stringify(support_roster_entry))
		return {}
	if _commander_entry_army_strength(support_roster_entry) > 0:
		_fail("Released post-capture support commander kept duplicated army continuity: %s" % JSON.stringify(support_roster_entry))
		return {}
	return {
		"case_id": "duplicate_assault_reinforces_newly_captured_town",
		"owner_after_capture": String(captured_town.get("owner", "")),
		"garrison_before_support": garrison_before,
		"garrison_after_support": garrison_after,
		"support_strength": support_strength,
		"support_resolved": _resolved_has(session, "neutral_town_sable_support"),
		"support_field_strength_after": support_army_strength_after,
		"stationed_commander_id": String(defended_town.get("ai_defender_roster_hero_id", "")),
		"support_commander_status_after": String(support_roster_entry.get("status", "")),
		"support_commander_army_after": _commander_entry_army_strength(support_roster_entry),
		"event_types": event_types,
		"defense_reason_codes": reason_codes,
		"message": message,
	}

func _stronger_support_rotates_town_defender_without_duplication() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	_prepare_neutral_town_only_front(session)
	_seed_task_board(session, [
		_town_expansion_task("hero_vaska", NEUTRAL_TOWN_ID, "active", "valid"),
		_town_expansion_task("hero_sable", NEUTRAL_TOWN_ID, "active", "valid"),
	])
	var capture_raid := _neutral_town_raid(session)
	var support_raid := _neutral_town_support_raid(session)
	support_raid["placement_id"] = "neutral_town_sable_strong_support"
	support_raid["enemy_army"] = {
		"id": "neutral_town_sable_strong_support_army",
		"name": "Strong Neutral Town Support Army",
		"stacks": [
			{"unit_id": "unit_blackbranch_cutthroat", "count": 16},
			{"unit_id": "unit_mire_slinger", "count": 8},
		],
	}
	support_raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		support_raid,
		"hero_sable",
		MIRECLAW,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW)
	)
	support_raid = EnemyAdventureRules.ensure_raid_army(support_raid, session)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(capture_raid)
	encounters.append(support_raid)
	session.overworld["encounters"] = encounters

	var capture_result := EnemyAdventureRules.advance_raids(
		session,
		config,
		MIRECLAW,
		state,
		{"only_placement_ids": ["neutral_town_vaska"]}
	)
	state = capture_result.get("state", state)
	var captured_town := _town(session, NEUTRAL_TOWN_ID)
	if String(captured_town.get("ai_defender_roster_hero_id", "")) != "hero_vaska":
		_fail("Stronger-support fixture did not start with Vaska stationed: %s" % JSON.stringify(captured_town))
		return {}
	var garrison_before := _army_strength(captured_town.get("garrison", []))

	var support_result := EnemyAdventureRules.advance_raids(
		session,
		config,
		MIRECLAW,
		state,
		{"only_placement_ids": ["neutral_town_sable_strong_support"]}
	)
	var defended_town := _town(session, NEUTRAL_TOWN_ID)
	var garrison_after := _army_strength(defended_town.get("garrison", []))
	if garrison_after <= garrison_before:
		_fail("Stronger support did not reinforce captured town: before=%d after=%d" % [garrison_before, garrison_after])
		return {}
	if String(defended_town.get("ai_defender_roster_hero_id", "")) != "hero_sable":
		_fail("Stronger support did not rotate into the town defender slot: %s" % JSON.stringify(defended_town))
		return {}
	var old_defender_entry := _commander_roster_entry(session, "hero_vaska")
	if String(old_defender_entry.get("status", "")) != EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE:
		_fail("Replaced town defender did not return to available roster status: %s" % JSON.stringify(old_defender_entry))
		return {}
	if _commander_entry_army_strength(old_defender_entry) > 0:
		_fail("Replaced town defender kept duplicated garrison army continuity: %s" % JSON.stringify(old_defender_entry))
		return {}
	var new_defender_entry := _commander_roster_entry(session, "hero_sable")
	if String(new_defender_entry.get("status", "")) != EnemyAdventureRules.COMMANDER_STATUS_ACTIVE or String(new_defender_entry.get("active_placement_id", "")) != "town_defense:%s" % NEUTRAL_TOWN_ID:
		_fail("Stronger support commander was not stationed after rotation: %s" % JSON.stringify(new_defender_entry))
		return {}
	if not _resolved_has(session, "neutral_town_sable_strong_support"):
		_fail("Stronger support field raid did not resolve into town defense.")
		return {}
	return {
		"case_id": "stronger_support_rotates_town_defender_without_duplication",
		"garrison_before_support": garrison_before,
		"garrison_after_support": garrison_after,
		"stationed_commander_id": String(defended_town.get("ai_defender_roster_hero_id", "")),
		"released_commander_id": "hero_vaska",
		"released_commander_status": String(old_defender_entry.get("status", "")),
		"released_commander_army_after": _commander_entry_army_strength(old_defender_entry),
		"event_types": _event_types(support_result.get("events", [])),
	}

func _defended_neutral_town_is_planned_assault_target() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	_prepare_neutral_town_only_front(session, _neutral_town_garrison())
	var result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	var task := _task_for_target(session, "town", NEUTRAL_TOWN_ID)
	if task.is_empty():
		_fail("Planner did not create a defended neutral-town expansion task: %s" % JSON.stringify(result))
		return {}
	var reason_codes := _string_array(task.get("priority_reason_codes", []))
	if "town_expansion" not in reason_codes or "neutral_town_claim" not in reason_codes or "neutral_town_siege" not in reason_codes:
		_fail("Defended neutral-town expansion task missed assault reason codes: %s" % JSON.stringify(task))
		return {}
	return {
		"case_id": "defended_neutral_town_is_planned_assault_target",
		"planned_count": int(result.get("planned_count", 0)),
		"task_id": String(task.get("task_id", "")),
		"target_kind": String(task.get("target_kind", "")),
		"target_id": String(task.get("target_id", "")),
		"reason_codes": reason_codes,
	}

func _weak_raid_delays_defended_neutral_town_assault() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_prepare_neutral_town_only_front(session, _neutral_town_garrison(24))
	var raid := _defended_neutral_town_raid(session, "weak_neutral_town_vaska", 3)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters
	var result := EnemyTurnRules._queue_town_defense_battle(session, config, MIRECLAW)
	if bool(result.get("battle_started", false)) or not session.battle.is_empty():
		_fail("Weak defended neutral-town assault should be delayed, not queued: %s" % JSON.stringify(result))
		return {}
	var after_raid := _encounter(session, "weak_neutral_town_vaska")
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	if "assault_risk_regroup" not in reason_codes and "assault_risk_staging" not in reason_codes:
		_fail("Weak defended neutral-town assault did not risk-gate: %s" % JSON.stringify(after_raid))
		return {}
	return {
		"case_id": "weak_raid_delays_defended_neutral_town_assault",
		"battle_started": false,
		"risk_gated": bool(result.get("risk_gated", false)),
		"reason_codes": reason_codes,
		"readiness_reason": String(result.get("readiness_report", {}).get("reason", "")),
	}

func _ready_raid_captures_defended_neutral_town_after_battle() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_prepare_neutral_town_only_front(session, _neutral_town_garrison())
	_add_safe_player_town(session)
	_seed_task_board(session, [_town_expansion_task("hero_vaska", NEUTRAL_TOWN_ID, "active", "valid")])
	var resources_before: Dictionary = session.overworld.get("resources", {}).duplicate(true)
	var raid := _defended_neutral_town_raid(session, "defended_neutral_town_vaska", 85)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters
	var result := EnemyTurnRules._queue_town_defense_battle(session, config, MIRECLAW)
	if not bool(result.get("battle_started", false)) or session.battle.is_empty():
		_fail("Ready defended neutral-town assault did not queue battle: %s" % JSON.stringify(result))
		return {}
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	if String(battle_context.get("type", "")) != "town_defense" or String(battle_context.get("defender_owner", "")) != "neutral":
		_fail("Defended neutral-town assault queued wrong battle context: %s" % JSON.stringify(battle_context))
		return {}
	_defeat_battle_side(session, "player")
	var outcome := BattleRules.resolve_if_battle_ready(session)
	if String(outcome.get("state", "")) != "town_lost":
		_fail("Defended neutral-town battle did not resolve as town_lost for neutral defender: %s" % JSON.stringify(outcome))
		return {}
	var town := _town(session, NEUTRAL_TOWN_ID)
	if String(town.get("owner", "neutral")) != "enemy" or String(town.get("controlling_faction_id", "")) != MIRECLAW:
		_fail("Defended neutral town was not captured into enemy control: %s" % JSON.stringify(town))
		return {}
	if _army_strength(town.get("garrison", [])) <= 0:
		_fail("Defended neutral-town capture did not preserve enemy survivor garrison: %s" % JSON.stringify(town))
		return {}
	if String(town.get("ai_defended_by_faction_id", "")) != MIRECLAW or String(town.get("ai_defender_roster_hero_id", "")) != "hero_vaska":
		_fail("Defended neutral-town capture did not station the assault commander: %s" % JSON.stringify(town))
		return {}
	var roster_entry := _commander_roster_entry(session, "hero_vaska")
	if String(roster_entry.get("status", "")) != EnemyAdventureRules.COMMANDER_STATUS_ACTIVE or String(roster_entry.get("active_placement_id", "")) != "town_defense:%s" % NEUTRAL_TOWN_ID:
		_fail("Defended neutral-town capture did not keep commander active in the captured town: %s" % JSON.stringify(roster_entry))
		return {}
	if String(roster_entry.get("last_outcome", "")) != EnemyAdventureRules.COMMANDER_OUTCOME_TOWN_CAPTURED:
		_fail("Defended neutral-town capture did not record town_captured outcome: %s" % JSON.stringify(roster_entry))
		return {}
	if JSON.stringify(resources_before) != JSON.stringify(session.overworld.get("resources", {})):
		_fail("Defended neutral-town loss changed player resources: before=%s after=%s" % [JSON.stringify(resources_before), JSON.stringify(session.overworld.get("resources", {}))])
		return {}
	_assert_task_status(session, "hero_vaska", "town", NEUTRAL_TOWN_ID, "completed", "valid")
	if _failed:
		return {}
	return {
		"case_id": "ready_raid_captures_defended_neutral_town_after_battle",
		"battle_started": true,
		"battle_context_type": String(battle_context.get("type", "")),
		"defender_owner": String(battle_context.get("defender_owner", "")),
		"outcome_state": String(outcome.get("state", "")),
		"owner_after": String(town.get("owner", "")),
		"controlling_faction_id": String(town.get("controlling_faction_id", "")),
		"garrison_strength_after": _army_strength(town.get("garrison", [])),
		"stationed_commander_status": String(roster_entry.get("status", "")),
		"stationed_commander_outcome": String(roster_entry.get("last_outcome", "")),
		"player_resources_unchanged": true,
	}

func _prepare_neutral_town_only_front(session, garrison: Array = []) -> void:
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) == "player":
			town["owner"] = "enemy"
			town["controlling_faction_id"] = MIRECLAW
			towns[index] = town
	towns.append({
		"placement_id": NEUTRAL_TOWN_ID,
		"town_id": "town_duskfen",
		"x": 8,
		"y": 2,
		"owner": "neutral",
		"garrison": garrison.duplicate(true),
		"available_recruits": {},
		"buildings": [],
	})
	session.overworld["towns"] = towns

func _add_safe_player_town(session) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == "riverwatch_hold":
			town["owner"] = "player"
			town["controlling_faction_id"] = ""
			towns[index] = town
			session.overworld["towns"] = towns
			return
	towns.append({
		"placement_id": "riverwatch_hold",
		"town_id": "town_riverwatch",
		"x": 1,
		"y": 1,
		"owner": "player",
		"controlling_faction_id": "",
		"garrison": [],
		"available_recruits": {},
		"buildings": [],
	})
	session.overworld["towns"] = towns

func _neutral_town_raid(session) -> Dictionary:
	var raid := {
		"placement_id": "neutral_town_vaska",
		"encounter_id": "encounter_mire_raid",
		"x": 8,
		"y": 2,
		"difficulty": "pressure",
		"combat_seed": hash("%s:neutral_town_vaska" % String(session.scenario_id)),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 0,
		"target_kind": "town",
		"target_placement_id": NEUTRAL_TOWN_ID,
		"target_label": "Mireford Neutral Hold",
		"target_x": 8,
		"target_y": 2,
		"goal_x": 8,
		"goal_y": 2,
		"target_reason_codes": ["town_expansion", "neutral_town_claim"],
		"target_public_reason": "neutral town expansion",
		"target_public_importance": "high",
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		"hero_vaska",
		MIRECLAW,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW)
	)
	return EnemyAdventureRules.ensure_raid_army(raid, session)

func _neutral_town_support_raid(session) -> Dictionary:
	var raid := _neutral_town_raid(session)
	raid["placement_id"] = "neutral_town_sable_support"
	raid["combat_seed"] = hash("%s:neutral_town_sable_support" % String(session.scenario_id))
	raid["x"] = 8
	raid["y"] = 3
	raid["goal_distance"] = 1
	raid["enemy_army"] = {
		"id": "neutral_town_sable_support_army",
		"name": "Neutral Town Support Army",
		"stacks": [
			{"unit_id": "unit_blackbranch_cutthroat", "count": 9},
			{"unit_id": "unit_mire_slinger", "count": 4},
		],
	}
	raid.erase("enemy_commander_state")
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		"hero_sable",
		MIRECLAW,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW)
	)
	return EnemyAdventureRules.ensure_raid_army(raid, session)

func _defended_neutral_town_raid(session, placement_id: String, mire_count: int) -> Dictionary:
	var raid := _neutral_town_raid(session)
	raid["placement_id"] = placement_id
	raid["combat_seed"] = hash("%s:%s" % [String(session.scenario_id), placement_id])
	raid["target_reason_codes"] = ["town_expansion", "neutral_town_claim", "neutral_town_siege"]
	raid["target_debug_reason"] = "defended neutral town expansion fixture"
	raid["enemy_army"] = {
		"id": "%s_army" % placement_id,
		"name": "%s Army" % placement_id,
		"stacks": [
			{"unit_id": "unit_blackbranch_cutthroat", "count": mire_count},
			{"unit_id": "unit_mire_slinger", "count": max(1, int(mire_count / 2))},
		],
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		"hero_vaska",
		MIRECLAW,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW)
	)
	return raid

func _neutral_town_garrison(count: int = 6) -> Array:
	return [
		{"unit_id": "unit_neutral_roadwardens", "count": count},
		{"unit_id": "unit_neutral_hearthbow_carriers", "count": max(1, int(count / 2))},
	]

func _base_session():
	var session = ScenarioFactory.create_session(
		RIVER_PASS,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
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

func _seed_task_board(session, tasks: Array) -> void:
	var state := _enemy_state(session)
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 17,
		"tasks": tasks,
	}
	_update_enemy_state(session, state)

func _town_expansion_task(actor_id: String, target_id: String, status: String, validation: String) -> Dictionary:
	return {
		"task_id": "task:town_expansion:%s:%s" % [actor_id, target_id],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "neutral_town_expansion_fixture",
		"task_class": "raid_town",
		"task_status": status,
		"target_kind": "town",
		"target_id": target_id,
		"front_id": "town:%s" % target_id,
		"origin_kind": "town",
		"origin_id": "duskfen_bastion",
		"priority_reason_codes": ["town_expansion", "neutral_town_claim"],
		"assigned_day": 2,
		"expires_day": 9,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": validation,
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "town:%s" % target_id,
		},
	}

func _task_for_target(session, target_kind: String, target_id: String) -> Dictionary:
	for task in _task_state(session).get("tasks", []):
		if not (task is Dictionary):
			continue
		if String(task.get("target_kind", "")) == target_kind and String(task.get("target_id", "")) == target_id:
			return task
	return {}

func _assert_task_status(session, actor_id: String, target_kind: String, target_id: String, status: String, validation: String) -> void:
	var task := _task_for_target(session, target_kind, target_id)
	if task.is_empty():
		_fail("Missing task %s/%s for %s" % [target_kind, target_id, actor_id])
		return
	if String(task.get("actor_id", "")) != actor_id or String(task.get("task_status", "")) != status or String(task.get("last_validation", "")) != validation:
		_fail("Task status mismatch: %s" % JSON.stringify(task))

func _task_state(session) -> Dictionary:
	var state := _enemy_state(session)
	return state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}

func _town(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _resolved_has(session, placement_id: String) -> bool:
	var resolved = session.overworld.get("resolved_encounters", [])
	return resolved is Array and placement_id in resolved

func _commander_roster_entry(session, actor_id: String) -> Dictionary:
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == actor_id:
			return entry
	return {}

func _commander_entry_army_strength(entry: Dictionary) -> int:
	var continuity: Dictionary = entry.get("army_continuity", {}) if entry.get("army_continuity", {}) is Dictionary else {}
	return _army_strength(continuity.get("stacks", []))

func _army_strength(stacks_value: Variant) -> int:
	var total := 0
	if not (stacks_value is Array):
		return total
	for stack in stacks_value:
		if not (stack is Dictionary):
			continue
		total += EnemyAdventureRules._unit_strength_value(String(stack.get("unit_id", ""))) * max(0, int(stack.get("count", 0)))
	return total

func _event_types(events: Variant) -> Array:
	var output := []
	if not (events is Array):
		return output
	for event in events:
		if event is Dictionary:
			output.append(String(event.get("event_type", "")))
	return output

func _event_reason_codes(events: Variant, event_type: String) -> Array:
	if not (events is Array):
		return []
	for event in events:
		if not (event is Dictionary):
			continue
		if String(event.get("event_type", "")) != event_type:
			continue
		var codes := _string_array(event.get("target_reason_codes", []))
		if codes.is_empty():
			codes = _string_array(event.get("reason_codes", []))
		return codes
	return []

func _defeat_battle_side(session, side: String) -> void:
	var stacks: Array = session.battle.get("stacks", []) if session.battle.get("stacks", []) is Array else []
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary) or String(stack.get("side", "")) != side:
			continue
		stack["total_health"] = 0
		stacks[index] = stack
	session.battle["stacks"] = stacks

func _string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for item in value:
		output.append(String(item))
	return output

func _fail(message: String) -> void:
	_failed = true
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
