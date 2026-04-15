extends Node

const SCENARIO_ID := "river-pass"
const DIFFICULTY_ID := "normal"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _run_end_turn_and_enemy_presence():
		return
	if not _run_auto_interaction_regressions():
		return
	if not _run_hostile_commander_identity_regression():
		return
	if not _run_hostile_commander_field_victory_regression():
		return
	if not _run_hostile_commander_recovery_regression():
		return
	if not _run_enemy_hero_intercept_regression():
		return
	if not _run_enemy_town_assault_regression():
		return
	if not _run_save_restore_hero_intercept_resume_regression():
		return
	if not _run_save_restore_town_assault_resume_regression():
		return
	if not _run_enemy_opening_turn_regression():
		return
	get_tree().quit(0)

func _run_end_turn_and_enemy_presence() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	_set_active_hero_movement(session, 0)
	SessionState.set_active_session(session)

	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	shell._on_end_turn_pressed()
	await get_tree().process_frame
	await get_tree().process_frame

	if int(session.day) != 2:
		push_error("Core systems smoke: end turn did not advance the day on first press.")
		get_tree().quit(1)
		return false

	var movement: Dictionary = session.overworld.get("movement", {})
	if int(movement.get("current", 0)) <= 0 or int(movement.get("current", 0)) != int(movement.get("max", 0)):
		push_error("Core systems smoke: end turn did not refresh movement to the daily maximum.")
		get_tree().quit(1)
		return false

	if EnemyTurnRules.active_raid_count(session, "faction_mireclaw") <= 0:
		shell._on_end_turn_pressed()
		await get_tree().process_frame
		await get_tree().process_frame
	if EnemyTurnRules.active_raid_count(session, "faction_mireclaw") <= 0:
		push_error("Core systems smoke: enemy turn did not restore hostile raid-host presence after day advance.")
		get_tree().quit(1)
		return false

	shell.queue_free()
	await get_tree().process_frame
	return true

func _run_auto_interaction_regressions() -> bool:
	if not _run_resource_auto_collect_regression():
		return false
	if not _run_encounter_auto_battle_regression():
		return false
	if not _run_enemy_town_context_regression():
		return false
	return true

func _run_resource_auto_collect_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	_set_active_hero_position(session, Vector2i(0, 0))
	var resource_before: int = int(session.overworld.get("resources", {}).get("wood", 0))
	var result := OverworldRules.try_move(session, 1, 0)
	var resource_node := _resource_node_by_placement(session, "north_timber")
	if not bool(result.get("ok", false)):
		push_error("Core systems smoke: stepping onto a resource site failed instead of auto-resolving.")
		get_tree().quit(1)
		return false
	if String(resource_node.get("collected_by_faction_id", "")) != "player":
		push_error("Core systems smoke: stepping onto a resource site did not auto-claim it.")
		get_tree().quit(1)
		return false
	if int(session.overworld.get("resources", {}).get("wood", 0)) <= resource_before:
		push_error("Core systems smoke: resource auto-claim did not award its stores.")
		get_tree().quit(1)
		return false
	return true

func _run_encounter_auto_battle_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Core systems smoke: sample scenario is missing an encounter for auto-battle coverage.")
		get_tree().quit(1)
		return false
	var encounter_tile := Vector2i(int(encounter.get("x", 0)), int(encounter.get("y", 0)))
	var staging_tile := _adjacent_open_tile(session, encounter_tile)
	if staging_tile.x < 0:
		push_error("Core systems smoke: could not find an approach tile for encounter auto-battle coverage.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(session, staging_tile)
	var delta := encounter_tile - staging_tile
	var result := OverworldRules.try_move(session, delta.x, delta.y)
	if String(result.get("route", "")) != "battle" or session.battle.is_empty():
		push_error("Core systems smoke: stepping onto an encounter did not auto-open battle flow.")
		get_tree().quit(1)
		return false
	return true

func _run_enemy_town_context_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var town := _town_by_placement(session, "duskfen_bastion")
	if town.is_empty():
		push_error("Core systems smoke: sample scenario is missing the hostile town coverage target.")
		get_tree().quit(1)
		return false
	var town_tile := Vector2i(int(town.get("x", 0)), int(town.get("y", 0)))
	var staging_tile := _adjacent_open_tile(session, town_tile)
	if staging_tile.x < 0:
		push_error("Core systems smoke: could not find an approach tile for hostile-town coverage.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(session, staging_tile)
	var delta := town_tile - staging_tile
	var result := OverworldRules.try_move(session, delta.x, delta.y)
	var updated_town := _town_by_placement(session, "duskfen_bastion")
	if not bool(result.get("ok", false)):
		push_error("Core systems smoke: moving onto the hostile town failed unexpectedly.")
		get_tree().quit(1)
		return false
	if String(updated_town.get("owner", "")) != "enemy":
		push_error("Core systems smoke: stepping onto a hostile town auto-converted ownership.")
		get_tree().quit(1)
		return false
	if String(result.get("route", "")) == "town" or TownRules.can_visit_active_town(session):
		push_error("Core systems smoke: hostile town entry still routes as a player town visit.")
		get_tree().quit(1)
		return false
	return true

func _run_hostile_commander_identity_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	_set_active_hero_position(session, Vector2i(2, 2))
	var raid := EnemyAdventureRules.ensure_raid_army(
		{
			"placement_id": "commander_identity_raid",
			"encounter_id": "encounter_mire_raid",
			"x": 3,
			"y": 2,
			"difficulty": "pressure",
			"combat_seed": 991200,
			"spawned_by_faction_id": "faction_mireclaw",
			"days_active": 1,
			"arrived": false,
			"goal_distance": 1,
			"target_kind": "town",
			"target_placement_id": "riverwatch_keep",
			"target_label": "Riverwatch Keep",
			"target_x": 5,
			"target_y": 2,
			"goal_x": 4,
			"goal_y": 2,
		},
		session
	)
	var commander_name := String(raid.get("enemy_commander_state", {}).get("name", ""))
	if commander_name == "":
		push_error("Core systems smoke: hostile raid did not gain a durable commander identity.")
		get_tree().quit(1)
		return false
	var encounters = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var threat_watch := OverworldRules.describe_frontier_threats(session)
	if commander_name not in threat_watch:
		push_error("Core systems smoke: frontier watch did not surface the visible hostile commander identity.")
		get_tree().quit(1)
		return false

	var result := OverworldRules.try_move(session, 1, 0)
	if String(result.get("route", "")) != "battle" or session.battle.is_empty():
		push_error("Core systems smoke: stepping onto a named hostile raid did not open battle.")
		get_tree().quit(1)
		return false
	if String(session.battle.get("enemy_hero", {}).get("name", "")) != commander_name:
		push_error("Core systems smoke: hostile commander identity did not carry from overworld raid into battle.")
		get_tree().quit(1)
		return false
	return true

func _run_hostile_commander_recovery_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	var states = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != "faction_mireclaw":
			continue
		var roster = state.get("commander_roster", [])
		for roster_index in range(roster.size()):
			var entry = roster[roster_index]
			if not (entry is Dictionary):
				continue
			entry["status"] = (
				EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE
				if roster_index == 0
				else EnemyAdventureRules.COMMANDER_STATUS_RECOVERING
			)
			entry["active_placement_id"] = ""
			entry["recovery_day"] = 0 if roster_index == 0 else session.day + 99
			roster[roster_index] = entry
		state["commander_roster"] = roster
		state["pressure"] = 0
		state["raid_counter"] = 0
		state["commander_counter"] = 0
		states[index] = state
		break
	session.overworld["enemy_states"] = states

	_set_active_hero_position(session, Vector2i(2, 2))
	var raid := EnemyAdventureRules.ensure_raid_army(
		{
			"placement_id": "commander_recovery_raid",
			"encounter_id": "encounter_mire_raid",
			"x": 3,
			"y": 2,
			"difficulty": "pressure",
			"combat_seed": 991299,
			"spawned_by_faction_id": "faction_mireclaw",
			"days_active": 1,
			"arrived": false,
			"goal_distance": 1,
			"target_kind": "town",
			"target_placement_id": "riverwatch_hold",
			"target_label": "Riverwatch Hold",
			"target_x": 0,
			"target_y": 2,
			"goal_x": 2,
			"goal_y": 2,
		},
		session
	)
	var commander_state: Dictionary = raid.get("enemy_commander_state", {})
	var roster_hero_id := String(commander_state.get("roster_hero_id", ""))
	var commander_name := String(commander_state.get("name", ""))
	if roster_hero_id == "" or commander_name == "":
		push_error("Core systems smoke: recovery setup failed to attach a named hostile commander.")
		get_tree().quit(1)
		return false
	var encounters = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters
	raid = _register_raid_commander_deployment(session, "faction_mireclaw", "commander_recovery_raid", roster_hero_id)
	if raid.is_empty():
		push_error("Core systems smoke: recovery setup could not register the hostile commander deployment.")
		get_tree().quit(1)
		return false
	var first_deployments := int(raid.get("enemy_commander_state", {}).get("deployments", 0))
	var first_desired_strength := EnemyAdventureRules.desired_raid_strength(raid)

	var engage_result := OverworldRules.try_move(session, 1, 0)
	if String(engage_result.get("route", "")) != "battle" or session.battle.is_empty():
		push_error("Core systems smoke: recovery setup failed to enter battle against the hostile commander.")
		get_tree().quit(1)
		return false
	for index in range(session.battle.get("stacks", []).size()):
		var stack = session.battle.get("stacks", [])[index]
		if not (stack is Dictionary) or String(stack.get("side", "")) != "enemy":
			continue
		stack["total_health"] = 0
		session.battle["stacks"][index] = stack
	var outcome := BattleRules.resolve_if_battle_ready(session)
	if String(outcome.get("state", "")) != "victory":
		push_error("Core systems smoke: hostile commander recovery coverage did not resolve through battle victory.")
		get_tree().quit(1)
		return false

	var recovering_entry := _enemy_commander_entry(_enemy_state_by_faction(session, "faction_mireclaw"), roster_hero_id)
	if String(recovering_entry.get("status", "")) != EnemyAdventureRules.COMMANDER_STATUS_RECOVERING:
		push_error("Core systems smoke: defeated hostile commander did not enter save-backed recovery.")
		get_tree().quit(1)
		return false
	var recovering_memory := EnemyAdventureRules.commander_target_memory(recovering_entry)
	if String(recovering_memory.get("focus_target_id", "")) != "riverwatch_hold":
		push_error("Core systems smoke: defeated hostile commander did not keep save-backed target memory for the pressured town.")
		get_tree().quit(1)
		return false
	var shattered_army := EnemyAdventureRules.commander_army_continuity(recovering_entry)
	if int(shattered_army.get("base_strength", 0)) <= 0 or int(shattered_army.get("current_strength", 0)) != 0:
		push_error("Core systems smoke: defeated hostile commander did not persist a shattered raid-host record.")
		get_tree().quit(1)
		return false
	if EnemyAdventureRules.commander_army_status(recovering_entry) != "shattered":
		push_error("Core systems smoke: defeated hostile commander did not surface a shattered army state.")
		get_tree().quit(1)
		return false
	var recovery_day := int(recovering_entry.get("recovery_day", 0))
	if recovery_day <= session.day:
		push_error("Core systems smoke: hostile commander recovery day was not scheduled into the future.")
		get_tree().quit(1)
		return false
	var threat_watch := OverworldRules.describe_frontier_threats(session)
	if "Command recovering" not in threat_watch or commander_name not in threat_watch:
		push_error("Core systems smoke: frontier watch did not expose hostile commander recovery after victory.")
		get_tree().quit(1)
		return false

	var restored = SessionState.new_session_data()
	restored.from_dict(session.to_dict())
	OverworldRules.normalize_overworld_state(restored)
	var restored_entry := _enemy_commander_entry(_enemy_state_by_faction(restored, "faction_mireclaw"), roster_hero_id)
	if String(restored_entry.get("status", "")) != EnemyAdventureRules.COMMANDER_STATUS_RECOVERING:
		push_error("Core systems smoke: restored session lost hostile commander recovery state.")
		get_tree().quit(1)
		return false
	if String(EnemyAdventureRules.commander_target_memory(restored_entry).get("focus_target_id", "")) != "riverwatch_hold":
		push_error("Core systems smoke: restored session lost hostile commander target memory.")
		get_tree().quit(1)
		return false
	if int(restored_entry.get("recovery_day", 0)) != recovery_day:
		push_error("Core systems smoke: restored hostile commander recovery timing changed unexpectedly.")
		get_tree().quit(1)
		return false

	_set_enemy_pressure(restored, "faction_mireclaw", 10)
	var raid_count_before := EnemyTurnRules.active_raid_count(restored, "faction_mireclaw")
	EnemyTurnRules.run_enemy_turn(restored)
	if EnemyTurnRules.active_raid_count(restored, "faction_mireclaw") != raid_count_before:
		push_error("Core systems smoke: hostile commander returned from defeat before the recovery rule elapsed.")
		get_tree().quit(1)
		return false

	restored.day = recovery_day
	_set_enemy_pressure(restored, "faction_mireclaw", 10)
	_limit_enemy_rebuild_capacity(restored, "faction_mireclaw")
	var return_result := EnemyTurnRules.run_enemy_turn(restored)
	if String(return_result.get("message", "")) == "":
		push_error("Core systems smoke: hostile commander recovery turn produced no feedback.")
		get_tree().quit(1)
		return false
	var returned_raid := _active_enemy_raid_by_roster_hero(restored, "faction_mireclaw", roster_hero_id)
	if returned_raid.is_empty():
		push_error("Core systems smoke: recovered hostile commander did not become eligible for a later raid.")
		get_tree().quit(1)
		return false
	if String(returned_raid.get("enemy_commander_state", {}).get("name", "")) != commander_name:
		push_error("Core systems smoke: recovered hostile commander returned without preserving identity.")
		get_tree().quit(1)
		return false
	if int(returned_raid.get("enemy_commander_state", {}).get("deployments", 0)) <= first_deployments:
		push_error("Core systems smoke: recovered hostile commander did not carry repeat-deployment record into the next raid.")
		get_tree().quit(1)
		return false
	if EnemyAdventureRules.desired_raid_strength(returned_raid) <= first_desired_strength:
		push_error("Core systems smoke: repeat hostile commander deployment did not raise future raid threat demand.")
		get_tree().quit(1)
		return false
	if EnemyAdventureRules.commander_veterancy_label(returned_raid.get("enemy_commander_state", {})) == "":
		push_error("Core systems smoke: recovered hostile commander returned without a visible veterancy label.")
		get_tree().quit(1)
		return false
	var returned_army := EnemyAdventureRules.commander_army_continuity(returned_raid.get("enemy_commander_state", {}))
	if int(returned_army.get("current_strength", 0)) <= 0:
		push_error("Core systems smoke: recovered hostile commander returned without any rebuilt army strength.")
		get_tree().quit(1)
		return false
	if int(returned_army.get("base_strength", 0)) > 0 and int(returned_army.get("current_strength", 0)) >= int(returned_army.get("base_strength", 0)):
		push_error("Core systems smoke: recovered hostile commander returned at full army strength instead of carrying rebuild scars.")
		get_tree().quit(1)
		return false
	if EnemyAdventureRules.raid_strength(returned_raid) != int(returned_army.get("current_strength", 0)):
		push_error("Core systems smoke: returning raid strength did not match the commander's rebuilt army continuity.")
		get_tree().quit(1)
		return false
	if EnemyAdventureRules.commander_army_brief(returned_raid.get("enemy_commander_state", {})) == "":
		push_error("Core systems smoke: recovered hostile commander returned without a visible rebuild or scar hint.")
		get_tree().quit(1)
		return false
	var returning_brief := EnemyAdventureRules.commander_memory_brief(returned_raid.get("enemy_commander_state", {}))
	if "returns to Riverwatch Hold" not in returning_brief:
		push_error("Core systems smoke: recovered hostile commander did not surface repeat target memory on the returning raid.")
		get_tree().quit(1)
		return false
	var public_memory := EnemyAdventureRules.raid_commander_memory_summaries([returned_raid], 1)
	if public_memory.is_empty() or "Riverwatch Hold" not in String(public_memory[0]):
		push_error("Core systems smoke: public commander-memory summaries did not expose the repeated target pressure.")
		get_tree().quit(1)
		return false
	return true

func _run_hostile_commander_field_victory_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	var states = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != "faction_mireclaw":
			continue
		var roster = state.get("commander_roster", [])
		for roster_index in range(roster.size()):
			var entry = roster[roster_index]
			if not (entry is Dictionary):
				continue
			entry["status"] = (
				EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE
				if roster_index == 0
				else EnemyAdventureRules.COMMANDER_STATUS_RECOVERING
			)
			entry["active_placement_id"] = ""
			entry["recovery_day"] = 0 if roster_index == 0 else session.day + 99
			roster[roster_index] = entry
		state["commander_roster"] = roster
		states[index] = state
		break
	session.overworld["enemy_states"] = states

	_set_active_hero_position(session, Vector2i(2, 2))
	var raid := EnemyAdventureRules.ensure_raid_army(
		{
			"placement_id": "commander_field_win_raid",
			"encounter_id": "encounter_mire_raid",
			"x": 3,
			"y": 2,
			"difficulty": "pressure",
			"combat_seed": 991177,
			"spawned_by_faction_id": "faction_mireclaw",
			"days_active": 1,
			"arrived": false,
			"goal_distance": 1,
			"target_kind": "hero",
			"target_placement_id": String(session.overworld.get("active_hero_id", "")),
			"target_label": String(session.overworld.get("hero", {}).get("name", "the hero")),
			"target_x": 2,
			"target_y": 2,
			"goal_x": 2,
			"goal_y": 2,
		},
		session
	)
	var roster_hero_id := String(raid.get("enemy_commander_state", {}).get("roster_hero_id", ""))
	if roster_hero_id == "":
		push_error("Core systems smoke: field-victory setup failed to assign a hostile commander.")
		get_tree().quit(1)
		return false
	var encounters = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters
	raid = _register_raid_commander_deployment(session, "faction_mireclaw", "commander_field_win_raid", roster_hero_id)
	if raid.is_empty():
		push_error("Core systems smoke: field-victory setup could not register the hostile commander deployment.")
		get_tree().quit(1)
		return false
	var desired_before := EnemyAdventureRules.desired_raid_strength(raid)

	var engage_result := OverworldRules.try_move(session, 1, 0)
	if String(engage_result.get("route", "")) != "battle" or session.battle.is_empty():
		push_error("Core systems smoke: field-victory setup failed to enter battle against the hostile commander.")
		get_tree().quit(1)
		return false
	var guard := 0
	while String(BattleRules.get_active_stack(session.battle).get("side", "")) == "enemy" and guard < 8:
		var autoplay := BattleRules.resolve_if_battle_ready(session)
		if String(autoplay.get("state", "")) == "invalid":
			push_error("Core systems smoke: field-victory setup produced an invalid enemy opening turn.")
			get_tree().quit(1)
			return false
		guard += 1
	for index in range(session.battle.get("stacks", []).size()):
		var stack = session.battle.get("stacks", [])[index]
		if not (stack is Dictionary) or String(stack.get("side", "")) != "enemy":
			continue
		stack["total_health"] = max(1, int(round(float(int(stack.get("total_health", 0))) * 0.55)))
		session.battle["stacks"][index] = stack
		break
	var retreat_result := BattleRules.perform_player_action(session, "retreat")
	if String(retreat_result.get("state", "")) != "retreat":
		push_error("Core systems smoke: retreat did not resolve the enemy field-victory continuity path.")
		get_tree().quit(1)
		return false

	var updated_raid := _active_enemy_raid_by_roster_hero(session, "faction_mireclaw", roster_hero_id)
	if updated_raid.is_empty():
		push_error("Core systems smoke: enemy field-victory continuity lost the active raid.")
		get_tree().quit(1)
		return false
	var updated_state: Dictionary = updated_raid.get("enemy_commander_state", {})
	var active_hero_id := String(session.overworld.get("active_hero_id", ""))
	var active_hero_name := String(session.overworld.get("hero", {}).get("name", "the hero"))
	var rivalry_memory := EnemyAdventureRules.commander_target_memory(updated_state)
	if String(rivalry_memory.get("rival_id", "")) != active_hero_id:
		push_error("Core systems smoke: hostile commander field victory did not record the opposing hero as a rivalry target.")
		get_tree().quit(1)
		return false
	if int(updated_state.get("battle_wins", 0)) <= 0:
		push_error("Core systems smoke: hostile commander field victory did not increment the battle-win record.")
		get_tree().quit(1)
		return false
	if EnemyAdventureRules.commander_veterancy_label(updated_state) == "":
		push_error("Core systems smoke: hostile commander field victory did not surface a veterancy label.")
		get_tree().quit(1)
		return false
	var scarred_army := EnemyAdventureRules.commander_army_continuity(updated_state)
	if int(scarred_army.get("current_strength", 0)) <= 0:
		push_error("Core systems smoke: hostile commander field victory lost the surviving raid host.")
		get_tree().quit(1)
		return false
	if int(scarred_army.get("base_strength", 0)) > 0 and int(scarred_army.get("current_strength", 0)) >= int(scarred_army.get("base_strength", 0)):
		push_error("Core systems smoke: hostile commander field victory did not keep partial army losses on the active raid.")
		get_tree().quit(1)
		return false
	if EnemyAdventureRules.raid_strength(updated_raid) != int(scarred_army.get("current_strength", 0)):
		push_error("Core systems smoke: active raid strength did not stay in sync with commander army continuity after retreat.")
		get_tree().quit(1)
		return false
	if EnemyAdventureRules.commander_army_brief(updated_state) == "":
		push_error("Core systems smoke: hostile commander field victory did not surface a scarred-host hint.")
		get_tree().quit(1)
		return false
	if EnemyAdventureRules.desired_raid_strength(updated_raid) <= desired_before:
		push_error("Core systems smoke: hostile commander field victory did not raise active raid threat demand.")
		get_tree().quit(1)
		return false
	var record_summary := EnemyAdventureRules.commander_record_summary(updated_state)
	if "win" not in record_summary:
		push_error("Core systems smoke: hostile commander field victory did not surface its battle record summary.")
		get_tree().quit(1)
		return false
	var enemy_config := _enemy_config(session, "faction_mireclaw")
	var baseline_plan := EnemyAdventureRules.choose_target(session, enemy_config, {"x": 7, "y": 1}, {})
	var repeat_rival_state := EnemyAdventureRules.record_rivalry(updated_state, "hero", active_hero_id, active_hero_name)
	var biased_plan := EnemyAdventureRules.choose_target(session, enemy_config, {"x": 7, "y": 1}, repeat_rival_state)
	if String(baseline_plan.get("target_placement_id", "")) == String(biased_plan.get("target_placement_id", "")):
		push_error("Core systems smoke: commander rivalry memory did not change later raid targeting.")
		get_tree().quit(1)
		return false
	if String(biased_plan.get("target_kind", "")) != "hero" or String(biased_plan.get("target_placement_id", "")) != active_hero_id:
		push_error("Core systems smoke: commander rivalry memory did not bias later raid targeting toward the repeated opposing hero.")
		get_tree().quit(1)
		return false

	var restored = SessionState.new_session_data()
	restored.from_dict(session.to_dict())
	OverworldRules.normalize_overworld_state(restored)
	var restored_raid := _active_enemy_raid_by_roster_hero(restored, "faction_mireclaw", roster_hero_id)
	if int(restored_raid.get("enemy_commander_state", {}).get("battle_wins", 0)) != int(updated_state.get("battle_wins", 0)):
		push_error("Core systems smoke: restored session lost hostile commander field-victory record.")
		get_tree().quit(1)
		return false
	if String(EnemyAdventureRules.commander_target_memory(restored_raid.get("enemy_commander_state", {})).get("rival_id", "")) != active_hero_id:
		push_error("Core systems smoke: restored session lost hostile commander rivalry memory.")
		get_tree().quit(1)
		return false
	return true

func _run_enemy_hero_intercept_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	_set_active_hero_position(session, Vector2i(2, 2))
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	var hero_name := String(session.overworld.get("hero", {}).get("name", "the hero"))
	var raid := EnemyAdventureRules.ensure_raid_army(
		{
			"placement_id": "intercept_smoke_raid",
			"encounter_id": "encounter_mire_raid",
			"x": 3,
			"y": 2,
			"difficulty": "pressure",
			"combat_seed": 991201,
			"spawned_by_faction_id": "faction_mireclaw",
			"days_active": 1,
			"arrived": false,
			"goal_distance": 1,
			"target_kind": "hero",
			"target_placement_id": hero_id,
			"target_label": hero_name,
			"target_x": 2,
			"target_y": 2,
			"goal_x": 2,
			"goal_y": 2,
		},
		session
	)
	var commander_name := String(raid.get("enemy_commander_state", {}).get("name", ""))
	var encounters = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyTurnRules.run_enemy_turn(session)
	if session.battle.is_empty():
		push_error("Core systems smoke: hero-targeting raid did not launch an interception battle.")
		get_tree().quit(1)
		return false
	if String(session.battle.get("context", {}).get("type", "")) != "hero_intercept":
		push_error("Core systems smoke: interception battle did not preserve hero-intercept context.")
		get_tree().quit(1)
		return false
	if String(result.get("message", "")) == "":
		push_error("Core systems smoke: interception launch returned no enemy-turn feedback.")
		get_tree().quit(1)
		return false
	if commander_name != "" and String(session.battle.get("enemy_hero", {}).get("name", "")) != commander_name:
		push_error("Core systems smoke: interception battle did not preserve the hostile commander identity.")
		get_tree().quit(1)
		return false
	return true

func _run_enemy_town_assault_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var town := _town_by_placement(session, "duskfen_bastion")
	if town.is_empty():
		push_error("Core systems smoke: sample scenario is missing the hostile town assault target.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(session, Vector2i(int(town.get("x", 0)), int(town.get("y", 0))))

	var result := OverworldRules.capture_active_town(session)
	if String(result.get("route", "")) != "battle" or session.battle.is_empty():
		push_error("Core systems smoke: hostile-town capture did not route into a town-assault battle.")
		get_tree().quit(1)
		return false
	if String(session.battle.get("context", {}).get("type", "")) != "town_assault":
		push_error("Core systems smoke: town assault battle did not preserve assault context.")
		get_tree().quit(1)
		return false
	if String(_town_by_placement(session, "duskfen_bastion").get("owner", "")) != "enemy":
		push_error("Core systems smoke: hostile-town assault flipped ownership before battle resolution.")
		get_tree().quit(1)
		return false

	for index in range(session.battle.get("stacks", []).size()):
		var stack = session.battle.get("stacks", [])[index]
		if not (stack is Dictionary) or String(stack.get("side", "")) != "enemy":
			continue
		stack["total_health"] = 0
		session.battle["stacks"][index] = stack
	var outcome := BattleRules.resolve_if_battle_ready(session)
	if String(outcome.get("state", "")) != "victory":
		push_error("Core systems smoke: town assault victory did not resolve through the standard battle flow.")
		get_tree().quit(1)
		return false
	if String(_town_by_placement(session, "duskfen_bastion").get("owner", "")) != "player":
		push_error("Core systems smoke: town assault victory did not transfer town ownership.")
		get_tree().quit(1)
		return false
	return true

func _run_save_restore_hero_intercept_resume_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	_set_active_hero_position(session, Vector2i(2, 2))
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	var hero_name := String(session.overworld.get("hero", {}).get("name", "the hero"))
	var raid := EnemyAdventureRules.ensure_raid_army(
		{
			"placement_id": "intercept_resume_raid",
			"encounter_id": "encounter_mire_raid",
			"x": 3,
			"y": 2,
			"difficulty": "pressure",
			"combat_seed": 991202,
			"spawned_by_faction_id": "faction_mireclaw",
			"days_active": 1,
			"arrived": false,
			"goal_distance": 1,
			"target_kind": "hero",
			"target_placement_id": hero_id,
			"target_label": hero_name,
			"target_x": 2,
			"target_y": 2,
			"goal_x": 2,
			"goal_y": 2,
		},
		session
	)
	var commander_name := String(raid.get("enemy_commander_state", {}).get("name", ""))
	var encounters = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyTurnRules.run_enemy_turn(session)
	if session.battle.is_empty() or String(result.get("message", "")) == "":
		push_error("Core systems smoke: interception save/restore setup did not create a live battle.")
		get_tree().quit(1)
		return false

	session.game_state = "overworld"
	var path := SaveService.save_manual_session(session.to_dict(), 2)
	if path == "":
		push_error("Core systems smoke: interception save/restore setup could not write the manual slot.")
		get_tree().quit(1)
		return false
	var summary := SaveService.inspect_manual_slot(2)
	if not SaveService.can_load_summary(summary):
		push_error("Core systems smoke: interception save summary was not loadable after restore normalization.")
		get_tree().quit(1)
		return false
	if String(summary.get("resume_target", "")) != "battle":
		push_error("Core systems smoke: interception save summary did not prefer battle resume when battle state existed.")
		get_tree().quit(1)
		return false
	if String(summary.get("battle_name", "")) == "":
		push_error("Core systems smoke: interception save summary did not expose the battle name for resume context.")
		get_tree().quit(1)
		return false

	var restored = SaveService.restore_session_from_summary(summary)
	if restored == null:
		push_error("Core systems smoke: interception save could not be restored through the public save service.")
		get_tree().quit(1)
		return false
	if String(restored.battle.get("context", {}).get("type", "")) != "hero_intercept":
		push_error("Core systems smoke: interception restore lost the hero-intercept battle context.")
		get_tree().quit(1)
		return false
	if String(restored.game_state) != "battle" or SaveService.resume_target_for_session(restored) != "battle":
		push_error("Core systems smoke: interception restore did not normalize back to battle resume.")
		get_tree().quit(1)
		return false
	if String(restored.overworld.get("active_hero_id", "")) != String(restored.battle.get("context", {}).get("target_hero_id", "")):
		push_error("Core systems smoke: interception restore did not keep the intercepted hero active for resume.")
		get_tree().quit(1)
		return false
	if commander_name != "" and String(restored.battle.get("enemy_hero", {}).get("name", "")) != commander_name:
		push_error("Core systems smoke: interception restore did not preserve hostile commander identity.")
		get_tree().quit(1)
		return false
	return true

func _run_save_restore_town_assault_resume_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var town := _town_by_placement(session, "duskfen_bastion")
	if town.is_empty():
		push_error("Core systems smoke: sample scenario is missing the hostile town assault restore target.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(session, Vector2i(int(town.get("x", 0)), int(town.get("y", 0))))

	var result := OverworldRules.capture_active_town(session)
	if String(result.get("route", "")) != "battle" or session.battle.is_empty():
		push_error("Core systems smoke: town-assault save/restore setup did not create a live assault battle.")
		get_tree().quit(1)
		return false

	var degraded_battle: Dictionary = session.battle.duplicate(true)
	degraded_battle.erase("context")
	degraded_battle.erase("stacks")
	session.battle = degraded_battle
	_set_town_owner(session, "duskfen_bastion", "player")
	session.game_state = "overworld"

	var path := SaveService.save_manual_session(session.to_dict(), 3)
	if path == "":
		push_error("Core systems smoke: town-assault save/restore setup could not write the manual slot.")
		get_tree().quit(1)
		return false
	var summary := SaveService.inspect_manual_slot(3)
	if not SaveService.can_load_summary(summary):
		push_error("Core systems smoke: town-assault save summary was not loadable after restore normalization.")
		get_tree().quit(1)
		return false
	if String(summary.get("resume_target", "")) != "battle":
		push_error("Core systems smoke: town-assault save summary did not prefer battle resume when battle state existed.")
		get_tree().quit(1)
		return false
	if String(summary.get("battle_name", "")) == "":
		push_error("Core systems smoke: town-assault save summary did not expose the assault battle name.")
		get_tree().quit(1)
		return false

	var restored = SaveService.restore_session_from_summary(summary)
	if restored == null:
		push_error("Core systems smoke: town-assault save could not be restored through the public save service.")
		get_tree().quit(1)
		return false
	if String(restored.battle.get("context", {}).get("type", "")) != "town_assault":
		push_error("Core systems smoke: town-assault restore lost the assault battle context.")
		get_tree().quit(1)
		return false
	if restored.battle.get("stacks", []).is_empty():
		push_error("Core systems smoke: town-assault restore did not rebuild missing battle stacks.")
		get_tree().quit(1)
		return false
	if String(_town_by_placement(restored, "duskfen_bastion").get("owner", "")) != "enemy":
		push_error("Core systems smoke: town-assault restore did not re-anchor hostile town ownership before battle resume.")
		get_tree().quit(1)
		return false
	if String(restored.game_state) != "battle" or SaveService.resume_target_for_session(restored) != "battle":
		push_error("Core systems smoke: town-assault restore did not normalize back to battle resume.")
		get_tree().quit(1)
		return false
	return true

func _run_enemy_opening_turn_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Core systems smoke: sample scenario is missing an encounter for enemy-turn coverage.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Core systems smoke: could not create a battle payload for enemy-turn coverage.")
		get_tree().quit(1)
		return false

	var enemy_first_id := _first_battle_stack_id(session.battle, "enemy")
	if enemy_first_id == "":
		push_error("Core systems smoke: battle payload has no enemy stack for enemy-turn coverage.")
		get_tree().quit(1)
		return false

	var reordered_turn_order := [enemy_first_id]
	for battle_id_value in session.battle.get("turn_order", []):
		var battle_id := String(battle_id_value)
		if battle_id == "" or battle_id == enemy_first_id:
			continue
		reordered_turn_order.append(battle_id)
	session.battle["turn_order"] = reordered_turn_order
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = enemy_first_id
	session.battle["selected_target_id"] = ""

	var recent_before := int(session.battle.get("recent_events", []).size())
	var result := BattleRules.resolve_if_battle_ready(session)
	var recent_after := int(session.battle.get("recent_events", []).size())
	var active_stack := BattleRules.get_active_stack(session.battle)
	if String(result.get("state", "continue")) == "invalid":
		push_error("Core systems smoke: battle opening autoplay produced an invalid enemy turn.")
		get_tree().quit(1)
		return false
	if session.scenario_status == "in_progress" and not active_stack.is_empty() and String(active_stack.get("side", "")) == "enemy":
		push_error("Core systems smoke: enemy opening turns did not execute back to a player response window.")
		get_tree().quit(1)
		return false
	if recent_after <= recent_before and String(result.get("message", "")) == "":
		push_error("Core systems smoke: enemy opening autoplay produced no battle activity.")
		get_tree().quit(1)
		return false
	return true

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _set_active_hero_movement(session, current: int) -> void:
	var max_movement := int(session.overworld.get("movement", {}).get("max", 0))
	var movement := {"current": clamp(current, 0, max_movement), "max": max_movement}
	session.overworld["movement"] = movement.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["movement"] = movement.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["movement"] = movement.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _resource_node_by_placement(session, placement_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return node
	return {}

func _town_by_placement(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _set_town_owner(session, placement_id: String, owner: String) -> void:
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			town["owner"] = owner
			towns[index] = town
			break
	session.overworld["towns"] = towns

func _enemy_state_by_faction(session, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state
	return {}

func _enemy_commander_entry(state: Dictionary, roster_hero_id: String) -> Dictionary:
	for entry in state.get("commander_roster", []):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == roster_hero_id:
			return entry
	return {}

func _register_raid_commander_deployment(
	session,
	faction_id: String,
	placement_id: String,
	roster_hero_id: String
) -> Dictionary:
	var states = session.overworld.get("enemy_states", [])
	var updated_roster := []
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		updated_roster = EnemyAdventureRules.record_commander_deployment(
			session,
			faction_id,
			roster_hero_id,
			state.get("commander_roster", []),
			placement_id
		)
		state["commander_roster"] = updated_roster
		states[index] = state
		break
	session.overworld["enemy_states"] = states

	var encounters = session.overworld.get("encounters", [])
	for index in range(encounters.size()):
		var encounter = encounters[index]
		if not (encounter is Dictionary) or String(encounter.get("placement_id", "")) != placement_id:
			continue
		encounter["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
			encounter,
			roster_hero_id,
			faction_id,
			session,
			{},
			updated_roster
		)
		encounters[index] = encounter
		session.overworld["encounters"] = encounters
		return encounter
	session.overworld["encounters"] = encounters
	return {}

func _set_enemy_pressure(session, faction_id: String, amount: int) -> void:
	var states = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		state["pressure"] = amount
		states[index] = state
		break
	session.overworld["enemy_states"] = states

func _limit_enemy_rebuild_capacity(session, faction_id: String) -> void:
	var towns = session.overworld.get("towns", [])
	var constrained := false
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) != "enemy":
			continue
		var town_template := ContentService.get_town(String(town.get("town_id", "")))
		if String(town_template.get("faction_id", "")) != faction_id:
			town["available_recruits"] = {}
			towns[index] = town
			continue
		if constrained:
			town["available_recruits"] = {}
			towns[index] = town
			continue
		var limited_recruits := {}
		var recruit_source = town.get("available_recruits", {})
		if not (recruit_source is Dictionary) or recruit_source.is_empty():
			recruit_source = OverworldRules.town_weekly_growth(town, session)
		for unit_id_value in recruit_source.keys():
			var unit_id := String(unit_id_value)
			if unit_id == "":
				continue
			limited_recruits[unit_id] = 1
			constrained = true
			break
		town["available_recruits"] = limited_recruits
		towns[index] = town
	session.overworld["towns"] = towns

func _active_enemy_raid_by_roster_hero(session, faction_id: String, roster_hero_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != faction_id:
			continue
		if OverworldRules.is_encounter_resolved(session, encounter):
			continue
		if String(encounter.get("enemy_commander_state", {}).get("roster_hero_id", "")) == roster_hero_id:
			return encounter
	return {}

func _enemy_config(session, faction_id: String) -> Dictionary:
	var scenario := ContentService.get_scenario(String(session.scenario_id))
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	return {}

func _first_encounter(session) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary:
			return encounter
	return {}

func _adjacent_open_tile(session, target: Vector2i) -> Vector2i:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var tile: Vector2i = target + offset
		if tile.x < 0 or tile.y < 0:
			continue
		var map_size: Vector2i = OverworldRules.derive_map_size(session)
		if tile.x >= map_size.x or tile.y >= map_size.y:
			continue
		if OverworldRules.tile_is_blocked(session, tile.x, tile.y):
			continue
		return tile
	return Vector2i(-1, -1)

func _first_battle_stack_id(battle: Dictionary, side: String) -> String:
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("side", "")) == side:
			return String(stack.get("battle_id", ""))
	return ""
