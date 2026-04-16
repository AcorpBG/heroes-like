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
	if not _run_battle_exit_aftermath_regression():
		return
	if not _run_battlefield_cover_obstruction_regression():
		return
	if not _run_hostile_commander_recovery_regression():
		return
	if not _run_enemy_hero_intercept_regression():
		return
	if not _run_enemy_town_assault_regression():
		return
	if not _run_long_horizon_strategic_layer_regression():
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
	var active_session = SessionState.ensure_active_session()

	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	shell._on_end_turn_pressed()
	await get_tree().process_frame
	await get_tree().process_frame

	if int(active_session.day) != 2:
		push_error("Core systems smoke: end turn did not advance the day on first press.")
		get_tree().quit(1)
		return false

	var movement: Dictionary = active_session.overworld.get("movement", {})
	if int(movement.get("current", 0)) <= 0 or int(movement.get("current", 0)) != int(movement.get("max", 0)):
		push_error("Core systems smoke: end turn did not refresh movement to the daily maximum.")
		get_tree().quit(1)
		return false

	if EnemyTurnRules.active_raid_count(active_session, "faction_mireclaw") <= 0:
		shell._on_end_turn_pressed()
		await get_tree().process_frame
		await get_tree().process_frame
	if EnemyTurnRules.active_raid_count(active_session, "faction_mireclaw") <= 0:
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
	EnemyTurnRules.normalize_enemy_states(session)
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
	EnemyTurnRules.normalize_enemy_states(session)
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

func _run_battle_exit_aftermath_regression() -> bool:
	var setup := _build_delivery_intercept_exit_setup()
	if setup.is_empty():
		return false

	var base_session = setup.get("session")
	var source_town_id := String(setup.get("source_town_id", ""))
	var node_id := String(setup.get("node_id", "river_free_company"))
	var roster_hero_id := String(setup.get("roster_hero_id", ""))
	var initial_recruits := int(setup.get("initial_recruits", 0))
	var post_response_recruits := int(setup.get("post_response_recruits", 0))

	var retreat_session = _clone_session(base_session)
	var retreat_pressure_before := int(_enemy_state_by_faction(retreat_session, "faction_mireclaw").get("pressure", 0))
	var retreat_gold_before := int(_enemy_state_by_faction(retreat_session, "faction_mireclaw").get("treasury", {}).get("gold", 0))
	var retreat_result := BattleRules.perform_player_action(retreat_session, "retreat")
	if String(retreat_result.get("state", "")) != "retreat":
		push_error("Core systems smoke: retreat did not resolve through the exit-aftermath coverage.")
		get_tree().quit(1)
		return false
	var retreat_town_total := _recruit_payload_total(_town_by_placement(retreat_session, source_town_id).get("available_recruits", {}))
	if retreat_town_total <= post_response_recruits or retreat_town_total >= initial_recruits:
		push_error("Core systems smoke: retreat did not scatter part of the live convoy back to its source town.")
		get_tree().quit(1)
		return false
	if _recruit_payload_total(_resource_node_by_placement(retreat_session, node_id).get("delivery_manifest", {})) > 0:
		push_error("Core systems smoke: retreat did not clear the live convoy state from the route.")
		get_tree().quit(1)
		return false
	var retreat_raid := _active_enemy_raid_by_roster_hero(retreat_session, "faction_mireclaw", roster_hero_id)
	if String(retreat_raid.get("enemy_commander_state", {}).get("last_outcome", "")) != EnemyAdventureRules.COMMANDER_OUTCOME_PURSUIT_VICTORY:
		push_error("Core systems smoke: retreat did not stamp the hostile commander with a pursuit-victory record.")
		get_tree().quit(1)
		return false
	var retreat_report: Dictionary = retreat_session.flags.get("last_battle_aftermath", {})
	if "scatters under pursuit" not in String(retreat_report.get("logistics_summary", "")):
		push_error("Core systems smoke: retreat aftermath did not record the convoy scatter summary.")
		get_tree().quit(1)
		return false
	var retreat_pressure_delta := int(_enemy_state_by_faction(retreat_session, "faction_mireclaw").get("pressure", 0)) - retreat_pressure_before
	var retreat_gold_delta := int(_enemy_state_by_faction(retreat_session, "faction_mireclaw").get("treasury", {}).get("gold", 0)) - retreat_gold_before
	var restored_retreat = _clone_session(retreat_session)
	if String(restored_retreat.flags.get("last_battle_aftermath", {}).get("logistics_summary", "")) != String(retreat_report.get("logistics_summary", "")):
		push_error("Core systems smoke: retreat aftermath summary did not survive save-style session cloning.")
		get_tree().quit(1)
		return false
	if String(_active_enemy_raid_by_roster_hero(restored_retreat, "faction_mireclaw", roster_hero_id).get("enemy_commander_state", {}).get("last_outcome", "")) != EnemyAdventureRules.COMMANDER_OUTCOME_PURSUIT_VICTORY:
		push_error("Core systems smoke: retreat commander pursuit state did not survive save-style session cloning.")
		get_tree().quit(1)
		return false

	var surrender_session = _clone_session(base_session)
	var surrender_pressure_before := int(_enemy_state_by_faction(surrender_session, "faction_mireclaw").get("pressure", 0))
	var surrender_gold_before := int(_enemy_state_by_faction(surrender_session, "faction_mireclaw").get("treasury", {}).get("gold", 0))
	var surrender_result := BattleRules.perform_player_action(surrender_session, "surrender")
	if String(surrender_result.get("state", "")) != "surrender":
		push_error("Core systems smoke: surrender did not resolve through the exit-aftermath coverage.")
		get_tree().quit(1)
		return false
	var surrender_town_total := _recruit_payload_total(_town_by_placement(surrender_session, source_town_id).get("available_recruits", {}))
	if surrender_town_total != post_response_recruits:
		push_error("Core systems smoke: surrender should not return convoy recruits to the source town.")
		get_tree().quit(1)
		return false
	var surrender_raid := _active_enemy_raid_by_roster_hero(surrender_session, "faction_mireclaw", roster_hero_id)
	if String(surrender_raid.get("enemy_commander_state", {}).get("last_outcome", "")) != EnemyAdventureRules.COMMANDER_OUTCOME_CAPITULATION:
		push_error("Core systems smoke: surrender did not stamp the hostile commander with a capitulation record.")
		get_tree().quit(1)
		return false
	var surrender_report: Dictionary = surrender_session.flags.get("last_battle_aftermath", {})
	if "handed over intact" not in String(surrender_report.get("logistics_summary", "")):
		push_error("Core systems smoke: surrender aftermath did not record the intact-convoy summary.")
		get_tree().quit(1)
		return false
	var surrender_pressure_delta := int(_enemy_state_by_faction(surrender_session, "faction_mireclaw").get("pressure", 0)) - surrender_pressure_before
	var surrender_gold_delta := int(_enemy_state_by_faction(surrender_session, "faction_mireclaw").get("treasury", {}).get("gold", 0)) - surrender_gold_before
	if surrender_gold_delta <= retreat_gold_delta:
		push_error("Core systems smoke: surrender did not transfer more treasury value than retreat.")
		get_tree().quit(1)
		return false
	if surrender_pressure_delta >= retreat_pressure_delta:
		push_error("Core systems smoke: surrender did not leave a lower hostile pressure spike than retreat.")
		get_tree().quit(1)
		return false

	var rout_session = _clone_session(base_session)
	var rout_pressure_before := int(_enemy_state_by_faction(rout_session, "faction_mireclaw").get("pressure", 0))
	var rout_gold_before := int(_enemy_state_by_faction(rout_session, "faction_mireclaw").get("treasury", {}).get("gold", 0))
	var rout_stacks = rout_session.battle.get("stacks", [])
	for index in range(rout_stacks.size()):
		var stack = rout_stacks[index]
		if stack is Dictionary and String(stack.get("side", "")) == "player":
			stack["total_health"] = 0
			rout_stacks[index] = stack
	rout_session.battle["stacks"] = rout_stacks
	var rout_result := BattleRules.resolve_if_battle_ready(rout_session)
	if String(rout_result.get("state", "")) != "defeat":
		push_error("Core systems smoke: routed-collapse coverage did not resolve into defeat.")
		get_tree().quit(1)
		return false
	var rout_raid := _active_enemy_raid_by_roster_hero(rout_session, "faction_mireclaw", roster_hero_id)
	if String(rout_raid.get("enemy_commander_state", {}).get("last_outcome", "")) != EnemyAdventureRules.COMMANDER_OUTCOME_ROUT_VICTORY:
		push_error("Core systems smoke: routed-collapse coverage did not stamp the hostile commander with a rout-victory record.")
		get_tree().quit(1)
		return false
	var rout_report: Dictionary = rout_session.flags.get("last_battle_aftermath", {})
	if "Battle Aftermath | Rout" not in String(rout_report.get("headline", "")):
		push_error("Core systems smoke: routed-collapse aftermath did not surface a rout headline.")
		get_tree().quit(1)
		return false
	var rout_pressure_delta := int(_enemy_state_by_faction(rout_session, "faction_mireclaw").get("pressure", 0)) - rout_pressure_before
	var rout_gold_delta := int(_enemy_state_by_faction(rout_session, "faction_mireclaw").get("treasury", {}).get("gold", 0)) - rout_gold_before
	if rout_pressure_delta <= retreat_pressure_delta:
		push_error("Core systems smoke: routed-collapse coverage did not create a harsher pressure spike than retreat.")
		get_tree().quit(1)
		return false
	if rout_gold_delta <= retreat_gold_delta:
		push_error("Core systems smoke: routed-collapse coverage did not strip more battlefield stores than retreat.")
		get_tree().quit(1)
		return false
	if "overrun in the rout" not in String(rout_report.get("logistics_summary", "")):
		push_error("Core systems smoke: routed-collapse aftermath did not record the convoy overrun summary.")
		get_tree().quit(1)
		return false
	return true

func _run_battlefield_cover_obstruction_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	session.battle = BattleRules.create_battle_payload(
		session,
		{
			"placement_id": "cover_obstruction_smoke",
			"encounter_id": "encounter_bone_ferry_watch",
			"x": 3,
			"y": 2,
			"combat_seed": 991240,
		}
	)
	if session.battle.is_empty():
		push_error("Core systems smoke: battlefield cover/obstruction coverage could not stage the authored encounter.")
		get_tree().quit(1)
		return false
	var player_ranged := _first_stack_for_side(session.battle, "player", true)
	var enemy_ranged := _first_stack_for_side(session.battle, "enemy", true)
	if player_ranged.is_empty() or enemy_ranged.is_empty():
		push_error("Core systems smoke: battlefield cover/obstruction coverage could not find the required ranged stacks.")
		get_tree().quit(1)
		return false

	var covered_preview: Dictionary = BattleRules._damage_range_preview(player_ranged, enemy_ranged, session.battle, true)
	var covered_attack_score := BattleAiRules._attack_score(player_ranged, enemy_ranged, session.battle, true)
	_set_battlefield_objective_state(session.battle, "bone_rack_cover_line", "neutral")
	var open_preview: Dictionary = BattleRules._damage_range_preview(player_ranged, enemy_ranged, session.battle, true)
	var open_attack_score := BattleAiRules._attack_score(player_ranged, enemy_ranged, session.battle, true)
	if int(open_preview.get("max_damage", 0)) <= int(covered_preview.get("max_damage", 0)):
		push_error("Core systems smoke: cover-line coverage did not blunt ranged damage into the screened target.")
		get_tree().quit(1)
		return false
	if open_attack_score <= covered_attack_score:
		push_error("Core systems smoke: battle AI scoring did not value the exposed target more once cover was removed.")
		get_tree().quit(1)
		return false

	_set_battlefield_objective_state(session.battle, "bone_rack_cover_line", "player")
	_set_battlefield_objective_state(session.battle, "ferry_chain_obstruction", "enemy", "player", 1)
	session.battle["distance"] = 2
	_force_battle_turn(session.battle, String(player_ranged.get("battle_id", "")), String(enemy_ranged.get("battle_id", "")), String(enemy_ranged.get("battle_id", "")))
	var blocked_result := BattleRules.perform_player_action(session, "advance")
	if not bool(blocked_result.get("ok", false)):
		push_error("Core systems smoke: battlefield obstruction coverage could not perform the player advance.")
		get_tree().quit(1)
		return false
	if int(session.battle.get("distance", -1)) != 2:
		push_error("Core systems smoke: obstruction-line coverage did not hold a weak advance on the current lane.")
		get_tree().quit(1)
		return false
	if "obstruction line" not in String(blocked_result.get("message", "")).to_lower():
		push_error("Core systems smoke: obstruction-line coverage did not surface the stalled-lane message.")
		get_tree().quit(1)
		return false
	var pressure_summary := BattleRules.describe_pressure(session)
	if "Terrain effect:" not in pressure_summary or "cover" not in pressure_summary.to_lower() or "obstruction" not in pressure_summary.to_lower():
		push_error("Core systems smoke: battle pressure summary did not surface compact terrain implications for cover and obstruction.")
		get_tree().quit(1)
		return false

	var restored = _clone_session(session)
	var restored_cover := _battlefield_objective(restored.battle, "bone_rack_cover_line")
	if String(restored_cover.get("control_side", "")) != "player":
		push_error("Core systems smoke: restored battle lost the cover-line controller state.")
		get_tree().quit(1)
		return false
	var restored_obstruction := _battlefield_objective(restored.battle, "ferry_chain_obstruction")
	if String(restored_obstruction.get("control_side", "")) != "enemy" or String(restored_obstruction.get("progress_side", "")) != "player" or int(restored_obstruction.get("progress_value", 0)) != 1:
		push_error("Core systems smoke: restored battle lost the obstruction-line contest state.")
		get_tree().quit(1)
		return false
	var restored_pressure := BattleRules.describe_pressure(restored)
	if "Friendly cover is blunting the opening volleys." not in restored_pressure:
		push_error("Core systems smoke: restored battle summary lost the cover-line pressure implication.")
		get_tree().quit(1)
		return false

	var clear_session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	clear_session.battle = BattleRules.create_battle_payload(
		clear_session,
		{
			"placement_id": "cover_obstruction_smoke_clear",
			"encounter_id": "encounter_bone_ferry_watch",
			"x": 3,
			"y": 2,
			"combat_seed": 991241,
		}
	)
	if clear_session.battle.is_empty():
		push_error("Core systems smoke: clear-lane control coverage could not stage the authored encounter.")
		get_tree().quit(1)
		return false
	var clear_player_ranged := _first_stack_for_side(clear_session.battle, "player", true)
	var clear_enemy_ranged := _first_stack_for_side(clear_session.battle, "enemy", true)
	_set_battlefield_objective_state(clear_session.battle, "ferry_chain_obstruction", "neutral")
	clear_session.battle["distance"] = 2
	_force_battle_turn(clear_session.battle, String(clear_player_ranged.get("battle_id", "")), String(clear_enemy_ranged.get("battle_id", "")), String(clear_enemy_ranged.get("battle_id", "")))
	var clear_result := BattleRules.perform_player_action(clear_session, "advance")
	if not bool(clear_result.get("ok", false)):
		push_error("Core systems smoke: clear-lane coverage could not perform the player advance.")
		get_tree().quit(1)
		return false
	if int(clear_session.battle.get("distance", -1)) != 1:
		push_error("Core systems smoke: removing the obstruction did not let the advance close the lane again.")
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

func _build_delivery_intercept_exit_setup() -> Dictionary:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var node_id := "river_free_company"
	var source_town_id := "riverwatch_hold"
	_set_town_available_recruits(
		session,
		source_town_id,
		{
			"unit_river_guard": 5,
			"unit_ember_archer": 3,
		}
	)
	var initial_recruits := _recruit_payload_total(_town_by_placement(session, source_town_id).get("available_recruits", {}))
	_set_resource_node_controller(session, node_id, "player")
	_set_active_hero_position(session, Vector2i(0, 4))
	_set_active_hero_movement(session, int(session.overworld.get("movement", {}).get("max", 0)))
	var response_result := OverworldRules.perform_context_action(session, "site_response")
	if not bool(response_result.get("ok", false)):
		push_error("Core systems smoke: exit-aftermath setup could not issue the live route-response order.")
		get_tree().quit(1)
		return {}
	var node := _resource_node_by_placement(session, node_id)
	var manifest_total := _recruit_payload_total(node.get("delivery_manifest", {}))
	if manifest_total <= 0:
		push_error("Core systems smoke: exit-aftermath setup did not load a live convoy manifest onto the route.")
		get_tree().quit(1)
		return {}
	var raid := EnemyAdventureRules.ensure_raid_army(
		{
			"placement_id": "exit_aftermath_raid",
			"encounter_id": "encounter_mire_raid",
			"x": 1,
			"y": 4,
			"difficulty": "pressure",
			"combat_seed": 991331,
			"spawned_by_faction_id": "faction_mireclaw",
			"days_active": 1,
			"arrived": true,
			"goal_distance": 0,
			"target_kind": "resource",
			"target_placement_id": node_id,
			"target_label": "Free Company Yard route",
			"goal_x": 0,
			"goal_y": 4,
			"delivery_intercept_node_placement_id": node_id,
		},
		session
	)
	var roster_hero_id := String(raid.get("enemy_commander_state", {}).get("roster_hero_id", ""))
	if roster_hero_id == "":
		push_error("Core systems smoke: exit-aftermath setup failed to assign a hostile commander to the route raid.")
		get_tree().quit(1)
		return {}
	var encounters = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters
	raid = _register_raid_commander_deployment(session, "faction_mireclaw", "exit_aftermath_raid", roster_hero_id)
	if raid.is_empty():
		push_error("Core systems smoke: exit-aftermath setup could not register the route-raid commander deployment.")
		get_tree().quit(1)
		return {}
	session.battle = BattleRules.create_battle_payload(session, raid)
	if session.battle.is_empty():
		push_error("Core systems smoke: exit-aftermath setup could not create the interception battle payload.")
		get_tree().quit(1)
		return {}
	var guard := 0
	while String(BattleRules.get_active_stack(session.battle).get("side", "")) == "enemy" and guard < 8:
		var autoplay := BattleRules.resolve_if_battle_ready(session)
		if String(autoplay.get("state", "")) == "invalid":
			push_error("Core systems smoke: exit-aftermath setup produced an invalid enemy opening turn.")
			get_tree().quit(1)
			return {}
		guard += 1
	if String(BattleRules.get_active_stack(session.battle).get("side", "")) != "player":
		push_error("Core systems smoke: exit-aftermath setup did not reach a player-controlled battle turn.")
		get_tree().quit(1)
		return {}
	return {
		"session": session,
		"node_id": node_id,
		"source_town_id": source_town_id,
		"roster_hero_id": roster_hero_id,
		"initial_recruits": initial_recruits,
		"post_response_recruits": _recruit_payload_total(_town_by_placement(session, source_town_id).get("available_recruits", {})),
	}

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
	var captured_town := _town_by_placement(session, "duskfen_bastion")
	if String(captured_town.get("owner", "")) != "player":
		push_error("Core systems smoke: town assault victory did not transfer town ownership.")
		get_tree().quit(1)
		return false
	var occupation: Dictionary = OverworldRules.town_occupation_state(session, captured_town)
	if not bool(occupation.get("active", false)) or String(occupation.get("mode", "")) != "pacifying":
		push_error("Core systems smoke: captured hostile town did not enter pacification.")
		get_tree().quit(1)
		return false
	if int(occupation.get("days_to_clear", 0)) <= 0:
		push_error("Core systems smoke: captured hostile town pacification did not persist a clearance window.")
		get_tree().quit(1)
		return false
	if int(occupation.get("locked_headcount", 0)) <= 0:
		push_error("Core systems smoke: captured hostile town did not hold back local recruits during pacification.")
		get_tree().quit(1)
		return false
	var base_income := OverworldRules.town_income(captured_town)
	var occupied_income := OverworldRules.town_income(captured_town, session)
	if int(occupied_income.get("gold", 0)) >= int(base_income.get("gold", 0)):
		push_error("Core systems smoke: occupied hostile town did not reduce income output.")
		get_tree().quit(1)
		return false
	if OverworldRules.town_battle_readiness(captured_town, session) >= OverworldRules.town_battle_readiness(captured_town):
		push_error("Core systems smoke: occupied hostile town did not reduce battle readiness.")
		get_tree().quit(1)
		return false
	var retake_front: Dictionary = OverworldRules.town_front_state(session, captured_town)
	if not bool(retake_front.get("active", false)) or String(retake_front.get("mode", "")) != "retake":
		push_error("Core systems smoke: captured hostile town did not persist a retake-front state.")
		get_tree().quit(1)
		return false
	if String(retake_front.get("faction_id", "")) != "faction_mireclaw":
		push_error("Core systems smoke: captured hostile town retake front did not keep the hostile faction anchor.")
		get_tree().quit(1)
		return false
	var town_summary := TownRules.describe_summary(session)
	if "retake front" not in town_summary.to_lower():
		push_error("Core systems smoke: town summary did not surface compact hostile retake pressure after capture.")
		get_tree().quit(1)
		return false
	if "occupation" not in town_summary.to_lower():
		push_error("Core systems smoke: town summary did not surface pacification after capture.")
		get_tree().quit(1)
		return false
	var frontier_watch := OverworldRules.describe_frontier_threats(session)
	if "Retake fronts retake Duskfen Bastion" not in frontier_watch:
		push_error("Core systems smoke: frontier watch did not surface the new hostile retake front after capture.")
		get_tree().quit(1)
		return false
	if "Occupation watch:" not in frontier_watch or "Duskfen Bastion" not in frontier_watch:
		push_error("Core systems smoke: frontier watch did not surface the occupied-town pacification watch.")
		get_tree().quit(1)
		return false
	var enemy_config := _enemy_config(session, "faction_mireclaw")
	var retake_plan := EnemyAdventureRules.choose_target(session, enemy_config, {"x": 7, "y": 1}, {})
	if String(retake_plan.get("target_kind", "")) != "town" or String(retake_plan.get("target_placement_id", "")) != "duskfen_bastion":
		push_error("Core systems smoke: hostile target scoring did not bias back toward the newly lost town.")
		get_tree().quit(1)
		return false
	var restored: Variant = SessionState.new_session_data()
	restored.from_dict(session.to_dict())
	OverworldRules.normalize_overworld_state(restored)
	var restored_front: Dictionary = OverworldRules.town_front_state(restored, _town_by_placement(restored, "duskfen_bastion"))
	if not bool(restored_front.get("active", false)) or String(restored_front.get("mode", "")) != "retake":
		push_error("Core systems smoke: restored session lost hostile retake-front continuity.")
		get_tree().quit(1)
		return false
	var restored_occupation: Dictionary = OverworldRules.town_occupation_state(restored, _town_by_placement(restored, "duskfen_bastion"))
	if not bool(restored_occupation.get("active", false)) or String(restored_occupation.get("mode", "")) != "pacifying":
		push_error("Core systems smoke: restored session lost occupied-town pacification continuity.")
		get_tree().quit(1)
		return false
	restored.day += 1
	var advanced: Dictionary = OverworldRules._advance_town_occupation(restored, _town_by_placement(restored, "duskfen_bastion"))
	var advanced_town: Dictionary = advanced.get("town", {})
	var advanced_occupation: Dictionary = OverworldRules.town_occupation_state(restored, advanced_town)
	if int(advanced_occupation.get("pressure", 0)) >= int(restored_occupation.get("pressure", 0)):
		push_error("Core systems smoke: occupied-town pacification did not advance on a new day.")
		get_tree().quit(1)
		return false
	var settling_town: Dictionary = captured_town.duplicate(true)
	var settling_occupation: Dictionary = settling_town.get("occupation", {})
	settling_occupation["pressure"] = 1
	settling_town["occupation"] = settling_occupation
	var settled: Dictionary = OverworldRules._advance_town_occupation(session, settling_town)
	var settled_town: Dictionary = settled.get("town", {})
	if bool(OverworldRules.town_occupation_state(session, settled_town).get("active", false)):
		push_error("Core systems smoke: occupied-town pacification did not clear after final relief.")
		get_tree().quit(1)
		return false
	if _recruit_payload_total(settled_town.get("available_recruits", {})) <= _recruit_payload_total(captured_town.get("available_recruits", {})):
		push_error("Core systems smoke: pacified town did not release held local recruits.")
		get_tree().quit(1)
		return false

	var stabilize_session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var stabilize_payload := BattleRules.create_town_assault_payload(stabilize_session, "duskfen_bastion")
	if stabilize_payload.is_empty():
		push_error("Core systems smoke: hostile-town stabilization coverage could not stage an assault payload.")
		get_tree().quit(1)
		return false
	stabilize_session.battle = stabilize_payload
	var retreat_result := BattleRules.perform_player_action(stabilize_session, "retreat")
	if String(retreat_result.get("state", "")) != "retreat":
		push_error("Core systems smoke: hostile-town stabilization coverage could not resolve a withdrawn assault.")
		get_tree().quit(1)
		return false
	var stabilized_front := OverworldRules.town_front_state(stabilize_session, _town_by_placement(stabilize_session, "duskfen_bastion"))
	if not bool(stabilized_front.get("active", false)) or String(stabilized_front.get("mode", "")) != "stabilizing":
		push_error("Core systems smoke: hostile town that held the assault did not enter stabilization posture.")
		get_tree().quit(1)
		return false
	if int(stabilized_front.get("days_remaining", 0)) <= 0:
		push_error("Core systems smoke: hostile town stabilization posture did not persist for a future day window.")
		get_tree().quit(1)
		return false
	return true

func _run_long_horizon_strategic_layer_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	if not _capture_duskfen_for_long_horizon(session):
		return false

	var captured_town := _town_by_placement(session, "duskfen_bastion")
	var occupation_before: Dictionary = OverworldRules.town_occupation_state(session, captured_town)
	var front_before: Dictionary = OverworldRules.town_front_state(session, captured_town)
	if not bool(occupation_before.get("active", false)) or not bool(front_before.get("active", false)):
		push_error("Core systems smoke: long-horizon setup did not create occupied retake-front town state.")
		get_tree().quit(1)
		return false

	var source_town_id := "riverwatch_hold"
	var route_node_id := "river_free_company"
	_set_resource_node_controller(session, route_node_id, "player")
	_set_town_available_recruits(
		session,
		source_town_id,
		{
			"unit_river_guard": 7,
			"unit_ember_archer": 5,
		}
	)
	var source_recruits_before := _recruit_payload_total(_town_by_placement(session, source_town_id).get("available_recruits", {}))
	_set_active_hero_position(session, Vector2i(0, 4))
	_set_active_hero_movement(session, int(session.overworld.get("movement", {}).get("max", 0)))
	var response_result := OverworldRules.perform_context_action(session, "site_response")
	if not bool(response_result.get("ok", false)):
		push_error("Core systems smoke: long-horizon route-response order could not be issued.")
		get_tree().quit(1)
		return false

	var route_node := _resource_node_by_placement(session, route_node_id)
	var delivery_state: Dictionary = OverworldRules._resource_site_delivery_state(session, route_node)
	if not bool(delivery_state.get("active", false)):
		push_error("Core systems smoke: long-horizon route-response order did not create a reserve convoy.")
		get_tree().quit(1)
		return false
	if String(delivery_state.get("target_kind", "")) != "town" or String(delivery_state.get("target_id", "")) != "duskfen_bastion":
		push_error("Core systems smoke: reserve convoy did not prioritize the occupied retake-front town.")
		get_tree().quit(1)
		return false
	if _recruit_payload_total(delivery_state.get("manifest", {})) <= 0:
		push_error("Core systems smoke: reserve convoy carried no recruits.")
		get_tree().quit(1)
		return false
	if _recruit_payload_total(_town_by_placement(session, source_town_id).get("available_recruits", {})) >= source_recruits_before:
		push_error("Core systems smoke: reserve convoy did not reserve recruits from its source town.")
		get_tree().quit(1)
		return false

	session.game_state = "overworld"
	var save_path := SaveService.save_manual_session(session.to_dict(), 1)
	if save_path == "":
		push_error("Core systems smoke: long-horizon convoy state could not be saved before day advance.")
		get_tree().quit(1)
		return false
	var summary := SaveService.inspect_manual_slot(1)
	if not SaveService.can_load_summary(summary):
		push_error("Core systems smoke: long-horizon convoy save summary was not loadable.")
		get_tree().quit(1)
		return false
	var restored = SaveService.restore_session_from_summary(summary)
	if restored == null:
		push_error("Core systems smoke: long-horizon convoy save did not restore through SaveService.")
		get_tree().quit(1)
		return false
	var restored_delivery: Dictionary = OverworldRules._resource_site_delivery_state(restored, _resource_node_by_placement(restored, route_node_id))
	if String(restored_delivery.get("target_id", "")) != "duskfen_bastion" or _recruit_payload_total(restored_delivery.get("manifest", {})) <= 0:
		push_error("Core systems smoke: restored long-horizon convoy lost its target or manifest.")
		get_tree().quit(1)
		return false
	if int(OverworldRules.town_occupation_state(restored, _town_by_placement(restored, "duskfen_bastion")).get("pressure", 0)) != int(occupation_before.get("pressure", 0)):
		push_error("Core systems smoke: restored long-horizon save changed occupied-town pressure before play resumed.")
		get_tree().quit(1)
		return false

	session = restored
	_append_route_disruption_raid(session, route_node_id)
	var block_state: Dictionary = OverworldRules._resource_site_delivery_interception(session, _resource_node_by_placement(session, route_node_id))
	if not bool(block_state.get("blocks_delivery", false)):
		push_error("Core systems smoke: route disruption raid did not block the active reserve convoy.")
		get_tree().quit(1)
		return false
	var target_garrison_before := _army_stack_headcount(_town_by_placement(session, "duskfen_bastion").get("garrison", []))
	var enemy_pressure_before := int(_enemy_state_by_faction(session, "faction_mireclaw").get("pressure", 0))
	var enemy_treasury_before := int(_enemy_state_by_faction(session, "faction_mireclaw").get("treasury", {}).get("gold", 0))
	var day_before := int(session.day)
	var turn_result := OverworldRules.end_turn(session)
	if not bool(turn_result.get("ok", false)):
		push_error("Core systems smoke: long-horizon day advance failed.")
		get_tree().quit(1)
		return false
	if int(session.day) != day_before + 1:
		push_error("Core systems smoke: long-horizon day advance did not increment the day.")
		get_tree().quit(1)
		return false
	var disrupted_node := _resource_node_by_placement(session, route_node_id)
	if String(disrupted_node.get("delivery_controller_id", "")) != "":
		push_error("Core systems smoke: disrupted reserve convoy was not cleared from the route.")
		get_tree().quit(1)
		return false
	if String(disrupted_node.get("collected_by_faction_id", "")) != "faction_mireclaw":
		push_error("Core systems smoke: route disruption did not transfer the logistics site to the hostile faction.")
		get_tree().quit(1)
		return false
	if _army_stack_headcount(_town_by_placement(session, "duskfen_bastion").get("garrison", [])) != target_garrison_before:
		push_error("Core systems smoke: blocked convoy still reinforced the occupied target town.")
		get_tree().quit(1)
		return false
	if int(_enemy_state_by_faction(session, "faction_mireclaw").get("pressure", 0)) <= enemy_pressure_before:
		push_error("Core systems smoke: route disruption did not raise hostile strategic pressure.")
		get_tree().quit(1)
		return false
	if int(_enemy_state_by_faction(session, "faction_mireclaw").get("treasury", {}).get("gold", 0)) <= enemy_treasury_before:
		push_error("Core systems smoke: route disruption did not add seized logistics value to hostile treasury.")
		get_tree().quit(1)
		return false
	var occupation_after: Dictionary = OverworldRules.town_occupation_state(session, _town_by_placement(session, "duskfen_bastion"))
	if int(occupation_after.get("pressure", 0)) >= int(occupation_before.get("pressure", 0)):
		push_error("Core systems smoke: occupied-town pacification did not progress across the long-horizon day.")
		get_tree().quit(1)
		return false
	var disrupted_restore = _clone_session(session)
	if String(_resource_node_by_placement(disrupted_restore, route_node_id).get("delivery_controller_id", "")) != "":
		push_error("Core systems smoke: restored disrupted route resurrected a cleared convoy.")
		get_tree().quit(1)
		return false
	if int(OverworldRules.town_occupation_state(disrupted_restore, _town_by_placement(disrupted_restore, "duskfen_bastion")).get("pressure", 0)) != int(occupation_after.get("pressure", 0)):
		push_error("Core systems smoke: restored disrupted route lost occupied-town pressure continuity.")
		get_tree().quit(1)
		return false

	if not _run_long_horizon_enemy_recruit_allocation_regression():
		return false
	return true

func _run_long_horizon_enemy_recruit_allocation_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var roster_hero_id := _stage_shattered_enemy_commander(session)
	if roster_hero_id == "":
		return false
	_set_enemy_pressure(session, "faction_mireclaw", 0)
	_set_enemy_treasury(session, "faction_mireclaw", {"gold": 9000, "wood": 80, "ore": 80})
	_set_town_garrison(session, "duskfen_bastion", [])
	_set_town_available_recruits(session, "duskfen_bastion", {"unit_mire_slinger": 4})
	var garrison_before := _army_stack_headcount(_town_by_placement(session, "duskfen_bastion").get("garrison", []))
	var rebuild_before := EnemyAdventureRules.commander_army_continuity(
		_enemy_commander_entry(_enemy_state_by_faction(session, "faction_mireclaw"), roster_hero_id)
	)
	if int(rebuild_before.get("current_strength", 0)) != 0 or int(rebuild_before.get("rebuild_need", 0)) <= 0:
		push_error("Core systems smoke: long-horizon rebuild setup did not create a shattered commander host.")
		get_tree().quit(1)
		return false
	EnemyTurnRules.run_enemy_turn(session)
	var garrison_after := _army_stack_headcount(_town_by_placement(session, "duskfen_bastion").get("garrison", []))
	var rebuild_after_garrison := EnemyAdventureRules.commander_army_continuity(
		_enemy_commander_entry(_enemy_state_by_faction(session, "faction_mireclaw"), roster_hero_id)
	)
	if garrison_after <= garrison_before:
		push_error("Core systems smoke: underdefended enemy town did not spend first recruits on its garrison.")
		get_tree().quit(1)
		return false
	if int(rebuild_after_garrison.get("current_strength", 0)) > 0:
		push_error("Core systems smoke: enemy recruitment rebuilt a commander before covering an exposed town.")
		get_tree().quit(1)
		return false

	var recovery_ready_entry := _enemy_commander_entry(_enemy_state_by_faction(session, "faction_mireclaw"), roster_hero_id)
	session.day = max(int(session.day), int(recovery_ready_entry.get("recovery_day", session.day)))
	_set_enemy_treasury(session, "faction_mireclaw", {"gold": 9000, "wood": 80, "ore": 80})
	_set_town_garrison(session, "duskfen_bastion", [{"unit_id": "unit_bog_brute", "count": 50}])
	_set_town_available_recruits(session, "duskfen_bastion", {"unit_mire_slinger": 5})
	EnemyTurnRules.run_enemy_turn(session)
	var rebuilt_entry := _enemy_commander_entry(_enemy_state_by_faction(session, "faction_mireclaw"), roster_hero_id)
	var rebuilt_continuity := EnemyAdventureRules.commander_army_continuity(rebuilt_entry)
	if int(rebuilt_continuity.get("current_strength", 0)) <= 0:
		push_error("Core systems smoke: defended enemy town did not spend later recruits on commander rebuild continuity.")
		get_tree().quit(1)
		return false
	if int(rebuilt_continuity.get("current_strength", 0)) >= int(rebuilt_continuity.get("base_strength", 0)):
		push_error("Core systems smoke: commander rebuild jumped to full strength instead of preserving long-horizon rebuild debt.")
		get_tree().quit(1)
		return false
	var restored = _clone_session(session)
	var restored_entry := _enemy_commander_entry(_enemy_state_by_faction(restored, "faction_mireclaw"), roster_hero_id)
	var restored_continuity := EnemyAdventureRules.commander_army_continuity(restored_entry)
	if int(restored_continuity.get("current_strength", 0)) != int(rebuilt_continuity.get("current_strength", 0)):
		push_error("Core systems smoke: restored long-horizon commander rebuild strength changed unexpectedly.")
		get_tree().quit(1)
		return false
	if EnemyAdventureRules.commander_army_brief(restored_entry) == "":
		push_error("Core systems smoke: rebuilt but scarred commander did not surface army-continuity detail.")
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

func _capture_duskfen_for_long_horizon(session) -> bool:
	var town := _town_by_placement(session, "duskfen_bastion")
	if town.is_empty():
		push_error("Core systems smoke: long-horizon coverage is missing Duskfen Bastion.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(session, Vector2i(int(town.get("x", 0)), int(town.get("y", 0))))
	var result := OverworldRules.capture_active_town(session)
	if String(result.get("route", "")) != "battle" or session.battle.is_empty():
		push_error("Core systems smoke: long-horizon setup could not enter the Duskfen assault battle.")
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
		push_error("Core systems smoke: long-horizon Duskfen assault did not resolve as a player victory.")
		get_tree().quit(1)
		return false
	if String(_town_by_placement(session, "duskfen_bastion").get("owner", "")) != "player":
		push_error("Core systems smoke: long-horizon Duskfen assault did not transfer ownership.")
		get_tree().quit(1)
		return false
	return true

func _append_route_disruption_raid(session, node_id: String) -> void:
	var node := _resource_node_by_placement(session, node_id)
	var raid := EnemyAdventureRules.ensure_raid_army(
		{
			"placement_id": "long_horizon_route_breaker",
			"encounter_id": "encounter_mire_raid",
			"x": int(node.get("x", 0)),
			"y": int(node.get("y", 0)),
			"difficulty": "pressure",
			"combat_seed": 991440,
			"spawned_by_faction_id": "faction_mireclaw",
			"days_active": 1,
			"arrived": true,
			"goal_distance": 0,
			"target_kind": "resource",
			"target_placement_id": node_id,
			"target_label": "Free Company Yard route",
			"goal_x": int(node.get("x", 0)),
			"goal_y": int(node.get("y", 0)),
			"delivery_intercept_node_placement_id": node_id,
		},
		session
	)
	var encounters = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

func _stage_shattered_enemy_commander(session) -> String:
	OverworldRules.normalize_overworld_state(session)
	EnemyTurnRules.normalize_enemy_states(session)
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
			entry["status"] = EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE
			entry["active_placement_id"] = ""
			entry["recovery_day"] = 0
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
			"placement_id": "long_horizon_rebuild_raid",
			"encounter_id": "encounter_mire_raid",
			"x": 3,
			"y": 2,
			"difficulty": "pressure",
			"combat_seed": 991441,
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
	var roster_hero_id := String(raid.get("enemy_commander_state", {}).get("roster_hero_id", ""))
	if roster_hero_id == "":
		push_error("Core systems smoke: long-horizon rebuild setup failed to assign a hostile commander.")
		get_tree().quit(1)
		return ""
	var encounters = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters
	raid = _register_raid_commander_deployment(session, "faction_mireclaw", "long_horizon_rebuild_raid", roster_hero_id)
	if raid.is_empty():
		push_error("Core systems smoke: long-horizon rebuild setup could not register commander deployment.")
		get_tree().quit(1)
		return ""
	var engage_result := OverworldRules.try_move(session, 1, 0)
	if String(engage_result.get("route", "")) != "battle" or session.battle.is_empty():
		push_error("Core systems smoke: long-horizon rebuild setup failed to enter commander battle.")
		get_tree().quit(1)
		return ""
	for stack_index in range(session.battle.get("stacks", []).size()):
		var stack = session.battle.get("stacks", [])[stack_index]
		if not (stack is Dictionary) or String(stack.get("side", "")) != "enemy":
			continue
		stack["total_health"] = 0
		session.battle["stacks"][stack_index] = stack
	var outcome := BattleRules.resolve_if_battle_ready(session)
	if String(outcome.get("state", "")) != "victory":
		push_error("Core systems smoke: long-horizon rebuild setup did not defeat the hostile commander.")
		get_tree().quit(1)
		return ""
	return roster_hero_id

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

func _recruit_payload_total(value: Variant) -> int:
	var total := 0
	if value is Dictionary:
		for unit_id_value in value.keys():
			total += max(0, int(value.get(unit_id_value, 0)))
	return total

func _set_town_owner(session, placement_id: String, owner: String) -> void:
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			town["owner"] = owner
			towns[index] = town
			break
	session.overworld["towns"] = towns

func _set_town_available_recruits(session, placement_id: String, recruits: Dictionary) -> void:
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			town["available_recruits"] = recruits.duplicate(true)
			towns[index] = town
			break
	session.overworld["towns"] = towns

func _set_town_garrison(session, placement_id: String, garrison: Array) -> void:
	var towns = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			town["garrison"] = garrison.duplicate(true)
			towns[index] = town
			break
	session.overworld["towns"] = towns

func _set_resource_node_controller(session, placement_id: String, controller_id: String) -> void:
	var nodes = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			node["collected_by_faction_id"] = controller_id
			nodes[index] = node
			break
	session.overworld["resource_nodes"] = nodes

func _set_enemy_treasury(session, faction_id: String, resources: Dictionary) -> void:
	var states = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		state["treasury"] = resources.duplicate(true)
		states[index] = state
		break
	session.overworld["enemy_states"] = states

func _army_stack_headcount(stacks: Variant) -> int:
	var total := 0
	if not (stacks is Array):
		return total
	for stack in stacks:
		if not (stack is Dictionary):
			continue
		total += max(0, int(stack.get("count", 0)))
	return total

func _clone_session(session):
	var clone = SessionState.new_session_data()
	clone.from_dict(session.to_dict())
	OverworldRules.normalize_overworld_state(clone)
	if not clone.battle.is_empty():
		BattleRules.normalize_battle_state(clone)
	return clone

func _first_stack_for_side(battle: Dictionary, side: String, ranged: bool) -> Dictionary:
	for stack in battle.get("stacks", []):
		if (
			stack is Dictionary
			and String(stack.get("side", "")) == side
			and bool(stack.get("ranged", false)) == ranged
			and int(stack.get("total_health", 0)) > 0
		):
			return stack
	return {}

func _battlefield_objective(battle: Dictionary, objective_id: String) -> Dictionary:
	for objective in battle.get("field_objectives", []):
		if objective is Dictionary and String(objective.get("id", "")) == objective_id:
			return objective
	return {}

func _set_battlefield_objective_state(
	battle: Dictionary,
	objective_id: String,
	control_side: String,
	progress_side: String = "",
	progress_value: int = 0
) -> void:
	var objectives = battle.get("field_objectives", [])
	for index in range(objectives.size()):
		var objective = objectives[index]
		if not (objective is Dictionary) or String(objective.get("id", "")) != objective_id:
			continue
		objective["control_side"] = control_side
		objective["progress_side"] = progress_side
		objective["progress_value"] = max(0, progress_value)
		objectives[index] = objective
		break
	battle["field_objectives"] = objectives

func _force_battle_turn(battle: Dictionary, active_id: String, target_id: String, next_enemy_id: String) -> void:
	battle["turn_order"] = [active_id, next_enemy_id]
	battle["turn_index"] = 0
	battle["active_stack_id"] = active_id
	battle["selected_target_id"] = target_id

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
