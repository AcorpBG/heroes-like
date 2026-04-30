extends Node

const SCENARIO_ID := "river-pass"
const DIFFICULTY_ID := "normal"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _run_end_turn_and_enemy_presence():
		return
	if not await _run_auto_interaction_regressions():
		return
	if not _run_overworld_memory_fog_regression():
		return
	if not _run_overworld_diagonal_movement_regression():
		return
	if not _run_neutral_dwelling_unit_slice_regression():
		return
	if not _run_hostile_commander_identity_regression():
		return
	if not _run_hostile_commander_field_victory_regression():
		return
	if not _run_battle_exit_aftermath_regression():
		return
	if not _run_town_defense_withdrawal_surface_regression():
		return
	if not _run_battlefield_cover_obstruction_regression():
		return
	if not _run_battle_hex_occupancy_legality_regression():
		return
	if not _run_battle_setup_move_target_continuity_regression():
		return
	if not _run_battle_direct_actionable_after_move_regression():
		return
	if not _run_battle_direct_actionable_after_move_invalidation_regression():
		return
	if not _run_battle_direct_actionable_after_move_direct_handoff_regression():
		return
	if not _run_battle_direct_actionable_after_move_prefers_attackable_handoff_regression():
		return
	if not _run_battle_direct_actionable_after_move_empty_handoff_regression():
		return
	if not _run_battle_setup_move_target_blocked_surface_regression():
		return
	if not _run_battle_spell_clears_closing_context_regression():
		return
	if not _run_battle_commander_spell_cadence_regression():
		return
	if not _run_hostile_commander_recovery_regression():
		return
	if not _run_enemy_hero_intercept_regression():
		return
	if not _run_enemy_town_assault_regression():
		return
	if not _run_long_horizon_strategic_layer_regression():
		return
	if not _run_extended_strategic_soak_regression():
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
	if not await _run_overworld_primary_action_regression():
		return false
	return true

func _run_overworld_memory_fog_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	var hero = session.overworld.get("hero", {})
	if HeroCommandRules.scouting_radius_for_hero(hero) != 3:
		push_error("Core systems smoke: base hero scouting radius did not include the requested +1 increase.")
		get_tree().quit(1)
		return false

	var start := OverworldRules.hero_position(session)
	var radius_edge := Vector2i(start.x + 3, start.y)
	if not OverworldRules.is_tile_visible(session, radius_edge.x, radius_edge.y):
		push_error("Core systems smoke: +1 scout radius did not reveal the distance-3 edge tile.")
		get_tree().quit(1)
		return false

	var never_seen := Vector2i(4, 0)
	if OverworldRules.is_tile_explored(session, never_seen.x, never_seen.y) or OverworldRules.is_tile_visible(session, never_seen.x, never_seen.y):
		push_error("Core systems smoke: initial fog did not hide an unscouted tile.")
		get_tree().quit(1)
		return false

	var initial_fog: Dictionary = session.overworld.get("fog", {})
	var initial_explored_count := int(initial_fog.get("explored_count", 0))
	var initial_visible_count := int(initial_fog.get("visible_count", 0))
	if initial_visible_count != initial_explored_count:
		push_error("Core systems smoke: HoMM-style fog should keep visible tiles aliased to explored tiles. fog=%s" % initial_fog)
		get_tree().quit(1)
		return false

	_set_active_hero_position(session, Vector2i(8, 2))
	OverworldRules.refresh_fog_of_war(session)
	var moved_fog: Dictionary = session.overworld.get("fog", {})
	if int(moved_fog.get("explored_count", 0)) < initial_explored_count or int(moved_fog.get("visible_count", 0)) < initial_visible_count:
		push_error("Core systems smoke: movement fog refresh shrank mapped visibility. before=%s after=%s" % [initial_fog, moved_fog])
		get_tree().quit(1)
		return false
	if not OverworldRules.is_tile_explored(session, start.x, start.y):
		push_error("Core systems smoke: explored start tile was not preserved as mapped memory after moving away.")
		get_tree().quit(1)
		return false
	if not OverworldRules.is_tile_visible(session, start.x, start.y):
		push_error("Core systems smoke: explored start tile did not remain visible under HoMM-style permanent fog.")
		get_tree().quit(1)
		return false
	if OverworldRules.is_tile_explored(session, never_seen.x, never_seen.y) or OverworldRules.is_tile_visible(session, never_seen.x, never_seen.y):
		push_error("Core systems smoke: unscouted tile became explored without entering a scout ring.")
		get_tree().quit(1)
		return false
	if int(moved_fog.get("visible_count", 0)) != int(moved_fog.get("explored_count", 0)):
		push_error("Core systems smoke: visible/explored counts diverged after movement fog refresh. fog=%s" % moved_fog)
		get_tree().quit(1)
		return false

	var missing_fog_session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	missing_fog_session.overworld.erase("fog")
	OverworldRules.normalize_overworld_state(missing_fog_session)
	if OverworldRules.is_tile_explored(missing_fog_session, never_seen.x, never_seen.y):
		push_error("Core systems smoke: missing fog state normalized to full-map exploration.")
		get_tree().quit(1)
		return false
	if not _run_homm_style_fog_move_expansion_regression():
		return false
	return true

func _run_homm_style_fog_move_expansion_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	var start := OverworldRules.hero_position(session)
	var before_fog: Dictionary = session.overworld.get("fog", {})
	var before_explored := int(before_fog.get("explored_count", 0))
	var before_visible := int(before_fog.get("visible_count", 0))
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var move_result := {}
	for direction in directions:
		var target := start + direction
		if target.x < 0 or target.y < 0:
			continue
		if OverworldRules.tile_is_blocked(session, target.x, target.y):
			continue
		move_result = OverworldRules.try_move(session, direction.x, direction.y)
		if bool(move_result.get("ok", false)):
			break
	if not bool(move_result.get("ok", false)):
		push_error("Core systems smoke: could not execute a one-step movement for HoMM-style fog expansion. result=%s" % move_result)
		get_tree().quit(1)
		return false
	var after_fog: Dictionary = session.overworld.get("fog", {})
	if int(after_fog.get("explored_count", 0)) < before_explored or int(after_fog.get("visible_count", 0)) < before_visible:
		push_error("Core systems smoke: try_move shrank permanent fog coverage. before=%s after=%s result=%s" % [before_fog, after_fog, move_result])
		get_tree().quit(1)
		return false
	if int(after_fog.get("visible_count", 0)) != int(after_fog.get("explored_count", 0)):
		push_error("Core systems smoke: try_move left visible tiles out of sync with permanent explored tiles. fog=%s" % after_fog)
		get_tree().quit(1)
		return false
	if not OverworldRules.is_tile_visible(session, start.x, start.y):
		push_error("Core systems smoke: try_move made the previous tile invisible despite permanent explored visibility.")
		get_tree().quit(1)
		return false
	return true

func _run_overworld_diagonal_movement_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	var start := OverworldRules.hero_position(session)
	var target := _diagonal_open_tile(session, start)
	if target.x < 0:
		push_error("Core systems smoke: could not find an open diagonal tile for overworld movement coverage.")
		get_tree().quit(1)
		return false
	var movement_before := int(session.overworld.get("movement", {}).get("current", 0))
	var delta := target - start
	var result := OverworldRules.try_move(session, delta.x, delta.y)
	var finish := OverworldRules.hero_position(session)
	var movement_after := int(session.overworld.get("movement", {}).get("current", 0))
	if not bool(result.get("ok", false)) or finish != target:
		push_error("Core systems smoke: diagonal overworld movement was rejected or landed on the wrong tile. result=%s start=%s target=%s finish=%s." % [result, start, target, finish])
		get_tree().quit(1)
		return false
	if movement_after != movement_before - 1:
		push_error("Core systems smoke: diagonal overworld movement did not cost exactly one movement point. before=%d after=%d result=%s." % [movement_before, movement_after, result])
		get_tree().quit(1)
		return false
	return true

func _run_neutral_dwelling_unit_slice_regression() -> bool:
	var roadwarden := ContentService.get_unit("unit_neutral_roadwardens")
	if roadwarden.is_empty() or String(roadwarden.get("affiliation", "")) != "neutral" or String(roadwarden.get("faction_id", "")) != "":
		push_error("Core systems smoke: neutral Roadwardens are not authored outside faction ladders.")
		get_tree().quit(1)
		return false

	var dwelling := ContentService.get_neutral_dwelling("neutral_dwelling_roadward_lodge")
	if dwelling.is_empty() or "unit_neutral_roadwardens" not in dwelling.get("unit_ids", []):
		push_error("Core systems smoke: Roadward Lodge family does not link to its neutral unit roster.")
		get_tree().quit(1)
		return false

	var site := ContentService.get_resource_site("site_free_company_yard")
	if String(site.get("dwelling_scope", "")) != "neutral" or String(site.get("neutral_dwelling_family_id", "")) != "neutral_dwelling_roadward_lodge":
		push_error("Core systems smoke: Free Company Yard is not wired as a neutral dwelling family site.")
		get_tree().quit(1)
		return false

	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var nodes = session.overworld.get("resource_nodes", [])
	nodes.append(
		{
			"placement_id": "neutral_test_roadward_lodge",
			"site_id": "site_free_company_yard",
			"x": 1,
			"y": 3,
		}
	)
	session.overworld["resource_nodes"] = nodes
	_set_active_hero_position(session, Vector2i(1, 3))

	var roadwardens_before := _army_unit_count(session.overworld.get("army", {}), "unit_neutral_roadwardens")
	var collect_result := OverworldRules.collect_active_resource(session)
	var claimed_node := _resource_node_by_placement(session, "neutral_test_roadward_lodge")
	var roadwardens_after := _army_unit_count(session.overworld.get("army", {}), "unit_neutral_roadwardens")
	if not bool(collect_result.get("ok", false)) or String(claimed_node.get("collected_by_faction_id", "")) != "player":
		push_error("Core systems smoke: neutral dwelling claim did not resolve through overworld rules.")
		get_tree().quit(1)
		return false
	if roadwardens_after <= roadwardens_before:
		push_error("Core systems smoke: neutral dwelling claim did not add neutral recruits to the field army.")
		get_tree().quit(1)
		return false

	var town_before := _recruit_unit_count(_town_by_placement(session, "riverwatch_hold").get("available_recruits", {}), "unit_neutral_roadwardens")
	var muster_messages := OverworldRules.apply_controlled_resource_site_musters(session, "player")
	var town_after := _recruit_unit_count(_town_by_placement(session, "riverwatch_hold").get("available_recruits", {}), "unit_neutral_roadwardens")
	if muster_messages.is_empty() or town_after <= town_before:
		push_error("Core systems smoke: controlled neutral dwelling did not feed weekly neutral musters to the nearest town.")
		get_tree().quit(1)
		return false

	var battle_payload := BattleRules.create_battle_payload(
		session,
		{
			"placement_id": "neutral_test_roadward_watch",
			"encounter_id": "encounter_roadward_lodge_watch",
			"x": 1,
			"y": 3,
			"combat_seed": 7711,
		}
	)
	if battle_payload.is_empty() or String(battle_payload.get("enemy_army_affiliation", "")) != "neutral":
		push_error("Core systems smoke: neutral encounter did not build a neutral battle payload.")
		get_tree().quit(1)
		return false
	var neutral_enemy_seen := false
	for stack in battle_payload.get("stacks", []):
		if not (stack is Dictionary) or String(stack.get("side", "")) != "enemy":
			continue
		if String(stack.get("affiliation", "")) == "neutral" and String(stack.get("faction_id", "")) == "":
			neutral_enemy_seen = true
			break
	if not neutral_enemy_seen:
		push_error("Core systems smoke: neutral encounter enemy stacks did not preserve neutral affiliation.")
		get_tree().quit(1)
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
	var resource_node := _resource_node_by_placement(session, "north_wood")
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

func _run_overworld_primary_action_regression() -> bool:
	var town_session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var town := _town_by_placement(town_session, "duskfen_bastion")
	if town.is_empty():
		push_error("Core systems smoke: sample scenario is missing Duskfen for primary action coverage.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(town_session, Vector2i(int(town.get("x", 0)), int(town.get("y", 0))))
	OverworldRules.refresh_fog_of_war(town_session)
	town_session = SessionState.set_active_session(town_session)
	var town_shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(town_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var town_snapshot: Dictionary = town_shell.call("validation_snapshot")
	if String(town_snapshot.get("primary_action_id", "")) != "capture_town":
		push_error("Core systems smoke: Duskfen did not expose capture as the overworld primary action.")
		get_tree().quit(1)
		return false
	town_shell.queue_free()
	await get_tree().process_frame

	var owned_town_session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var owned_town := _town_by_placement(owned_town_session, "duskfen_bastion")
	if owned_town.is_empty():
		push_error("Core systems smoke: sample scenario is missing Duskfen for owned-town primary action coverage.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(owned_town_session, Vector2i(int(owned_town.get("x", 0)), int(owned_town.get("y", 0))))
	var capture_result := OverworldRules.capture_active_town(owned_town_session)
	if String(capture_result.get("route", "")) != "battle" or owned_town_session.battle.is_empty():
		push_error("Core systems smoke: Duskfen setup did not stage a town-assault battle for owned-town primary action coverage.")
		get_tree().quit(1)
		return false
	if not _force_player_victory_if_battle_started(owned_town_session, "owned-town primary action setup"):
		return false
	var captured_town := _town_by_placement(owned_town_session, "duskfen_bastion")
	if String(captured_town.get("owner", "")) != "player":
		push_error("Core systems smoke: Duskfen setup did not transfer ownership for Visit Town primary action coverage.")
		get_tree().quit(1)
		return false
	OverworldRules.refresh_fog_of_war(owned_town_session)
	owned_town_session = SessionState.set_active_session(owned_town_session)
	var owned_town_shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(owned_town_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var owned_town_snapshot: Dictionary = owned_town_shell.call("validation_snapshot")
	if (
		String(owned_town_snapshot.get("primary_action_id", "")) != "visit_town"
		or bool(owned_town_snapshot.get("primary_action_button_disabled", true))
		or not String(owned_town_snapshot.get("primary_action_button_text", "")).begins_with("Visit Town")
	):
		push_error("Core systems smoke: owned Duskfen did not expose Visit Town as the rendered overworld primary action. %s" % JSON.stringify(owned_town_snapshot))
		get_tree().quit(1)
		return false
	owned_town_shell.queue_free()
	await get_tree().process_frame

	var resource_session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var resource_node := _resource_node_by_placement(resource_session, "north_wood")
	if resource_node.is_empty():
		push_error("Core systems smoke: sample scenario is missing north_wood for primary action coverage.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(resource_session, Vector2i(int(resource_node.get("x", 0)), int(resource_node.get("y", 0))))
	OverworldRules.refresh_fog_of_war(resource_session)
	resource_session = SessionState.set_active_session(resource_session)
	var resource_shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(resource_shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var resource_snapshot: Dictionary = resource_shell.call("validation_snapshot")
	if String(resource_snapshot.get("primary_action_id", "")) != "collect_resource":
		push_error("Core systems smoke: resource site did not expose collection as the overworld primary action.")
		get_tree().quit(1)
		return false
	var primary_result: Dictionary = resource_shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	var resource_after := _resource_node_by_placement(resource_session, "north_wood")
	if not bool(primary_result.get("ok", false)) or String(resource_after.get("collected_by_faction_id", "")) != "player":
		push_error("Core systems smoke: overworld primary action did not collect the active resource site. %s" % JSON.stringify({
			"primary_result": primary_result,
			"resource_after": resource_after,
			"resource_snapshot": resource_snapshot,
		}))
		get_tree().quit(1)
		return false
	resource_shell.queue_free()
	await get_tree().process_frame
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

func _run_town_defense_withdrawal_surface_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var town := _town_by_placement(session, "riverwatch_hold")
	if town.is_empty():
		push_error("Core systems smoke: town-defense withdrawal surface coverage is missing Riverwatch Hold.")
		get_tree().quit(1)
		return false
	var placement := {
		"placement_id": "town_defense_withdrawal_surface_probe",
		"encounter_id": "encounter_mire_raid",
		"x": int(town.get("x", 0)),
		"y": int(town.get("y", 0)),
		"combat_seed": 991268,
		"spawned_by_faction_id": "faction_mireclaw",
		"target_kind": "town",
		"target_placement_id": "riverwatch_hold",
		"target_label": String(town.get("name", "Riverwatch Hold")),
		"arrived": true,
		"goal_distance": 0,
		"battle_context": {
			"type": "town_defense",
			"town_placement_id": "riverwatch_hold",
			"defending_hero_id": "",
			"raid_encounter_key": "town_defense_withdrawal_surface_probe",
			"trigger_faction_id": "faction_mireclaw",
		},
	}
	session.battle = BattleRules.create_battle_payload(session, placement)
	session.game_state = "battle"
	if session.battle.is_empty() or String(session.battle.get("context", {}).get("type", "")) != "town_defense":
		push_error("Core systems smoke: town-defense withdrawal surface coverage could not stage a defense battle.")
		get_tree().quit(1)
		return false

	session.battle["retreat_allowed"] = true
	session.battle["surrender_allowed"] = true
	var restored = _clone_session(session)
	if restored == null or restored.battle.is_empty():
		push_error("Core systems smoke: stale town-defense withdrawal restore lost the battle payload.")
		get_tree().quit(1)
		return false
	var player_stack := _first_stack_for_side(restored.battle, "player", false)
	if player_stack.is_empty():
		player_stack = _first_stack_for_side(restored.battle, "player", true)
	var enemy_stack := _first_stack_for_side(restored.battle, "enemy", false)
	if enemy_stack.is_empty():
		enemy_stack = _first_stack_for_side(restored.battle, "enemy", true)
	if player_stack.is_empty() or enemy_stack.is_empty():
		push_error("Core systems smoke: town-defense withdrawal surface coverage lacks live opposing stacks.")
		get_tree().quit(1)
		return false
	_force_battle_turn(
		restored.battle,
		String(player_stack.get("battle_id", "")),
		String(enemy_stack.get("battle_id", "")),
		String(enemy_stack.get("battle_id", ""))
	)

	var surface: Dictionary = BattleRules.get_action_surface(restored)
	var retreat_action: Dictionary = surface.get("retreat", {}) if surface.get("retreat", {}) is Dictionary else {}
	var surrender_action: Dictionary = surface.get("surrender", {}) if surface.get("surrender", {}) is Dictionary else {}
	var retreat_summary := String(retreat_action.get("summary", "")).to_lower()
	var surrender_summary := String(surrender_action.get("summary", "")).to_lower()
	var pressure_summary := BattleRules.describe_pressure(restored)
	if (
		bool(restored.battle.get("retreat_allowed", true))
		or bool(restored.battle.get("surrender_allowed", true))
		or not bool(retreat_action.get("disabled", false))
		or not bool(surrender_action.get("disabled", false))
		or "defending a town" not in retreat_summary
		or "defending a town" not in surrender_summary
		or "Retreat: Locked" not in pressure_summary
		or "Surrender: Locked" not in pressure_summary
	):
		push_error("Core systems smoke: stale town-defense withdrawal flags leaked into player-facing action state: surface=%s pressure=%s battle=%s." % [surface, pressure_summary, restored.battle])
		get_tree().quit(1)
		return false

	var retreat_result := BattleRules.perform_player_action(restored, "retreat")
	var surrender_result := BattleRules.perform_player_action(restored, "surrender")
	if (
		bool(retreat_result.get("ok", false))
		or bool(surrender_result.get("ok", false))
		or String(retreat_result.get("state", "")) != "invalid"
		or String(surrender_result.get("state", "")) != "invalid"
		or "cannot abandon" not in String(retreat_result.get("message", "")).to_lower()
		or "cannot surrender" not in String(surrender_result.get("message", "")).to_lower()
	):
		push_error("Core systems smoke: town-defense withdrawal execution no longer matches the locked action surface: retreat=%s surrender=%s." % [retreat_result, surrender_result])
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
	var current_cover := _battlefield_objective(session.battle, "bone_rack_cover_line")
	var current_obstruction := _battlefield_objective(session.battle, "ferry_chain_obstruction")
	var restored_cover := _battlefield_objective(restored.battle, "bone_rack_cover_line")
	if (
		String(restored_cover.get("control_side", "")) != String(current_cover.get("control_side", ""))
		or String(restored_cover.get("progress_side", "")) != String(current_cover.get("progress_side", ""))
		or int(restored_cover.get("progress_value", 0)) != int(current_cover.get("progress_value", 0))
	):
		push_error("Core systems smoke: restored battle lost the cover-line controller state: current=%s restored=%s." % [current_cover, restored_cover])
		get_tree().quit(1)
		return false
	var restored_obstruction := _battlefield_objective(restored.battle, "ferry_chain_obstruction")
	if (
		String(restored_obstruction.get("control_side", "")) != String(current_obstruction.get("control_side", ""))
		or String(restored_obstruction.get("progress_side", "")) != String(current_obstruction.get("progress_side", ""))
		or int(restored_obstruction.get("progress_value", 0)) != int(current_obstruction.get("progress_value", 0))
	):
		push_error("Core systems smoke: restored battle lost the obstruction-line contest state: current=%s restored=%s." % [current_obstruction, restored_obstruction])
		get_tree().quit(1)
		return false
	var restored_pressure := BattleRules.describe_pressure(restored)
	if "Terrain effect:" not in restored_pressure or "cover" not in restored_pressure.to_lower() or "obstruction" not in restored_pressure.to_lower():
		push_error("Core systems smoke: restored battle summary lost the compact terrain implications for cover and obstruction.")
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
	if int(clear_session.battle.get("distance", -1)) >= 2:
		push_error("Core systems smoke: removing the obstruction did not let the advance close the lane again.")
		get_tree().quit(1)
		return false
	return true

func _run_battle_hex_occupancy_legality_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Core systems smoke: hex legality coverage could not find a battle encounter.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Core systems smoke: hex legality coverage could not create a battle payload.")
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(session)

	var occupancy: Dictionary = BattleRules.battle_occupancy_map(session.battle)
	var living_stacks := _living_battle_stack_count(session.battle)
	if occupancy.size() != living_stacks:
		push_error("Core systems smoke: battle hex occupancy did not match living stack count.")
		get_tree().quit(1)
		return false
	for stack in session.battle.get("stacks", []):
		if not (stack is Dictionary) or int(stack.get("total_health", 0)) <= 0:
			continue
		var hex := _stack_hex_for_test(stack)
		if hex.is_empty() or not occupancy.has(_hex_key_for_test(hex)):
			push_error("Core systems smoke: live stack is missing a saved occupied hex: %s." % stack)
			get_tree().quit(1)
			return false

	var player_melee := _first_stack_for_side(session.battle, "player", false)
	var enemy_melee := _first_stack_for_side(session.battle, "enemy", false)
	if player_melee.is_empty() or enemy_melee.is_empty():
		push_error("Core systems smoke: hex legality coverage could not find opposing melee stacks.")
		get_tree().quit(1)
		return false

	var player_id := String(player_melee.get("battle_id", ""))
	var enemy_id := String(enemy_melee.get("battle_id", ""))
	_set_stack_hex_for_test(session.battle, player_id, {"q": 4, "r": 3})
	_set_stack_hex_for_test(session.battle, enemy_id, {"q": 5, "r": 3})
	session.battle["distance"] = 0
	_force_battle_turn(session.battle, player_id, enemy_id, enemy_id)
	BattleRules.normalize_battle_state(session)
	if not bool(BattleRules.action_availability(session.battle).get("strike", false)):
		push_error("Core systems smoke: adjacent hexes did not make melee strike legal.")
		get_tree().quit(1)
		return false
	var adjacent_legality: Dictionary = BattleRules.selected_target_legality(session.battle)
	if not bool(adjacent_legality.get("attackable", false)) or bool(adjacent_legality.get("blocked", false)):
		push_error("Core systems smoke: adjacent selected target was not surfaced as attackable: %s." % adjacent_legality)
		get_tree().quit(1)
		return false
	var melee_click_intent: Dictionary = BattleRules.selected_target_board_click_intent(session.battle)
	if String(melee_click_intent.get("action", "")) != "strike" or String(melee_click_intent.get("label", "")) != "Strike":
		push_error("Core systems smoke: adjacent melee selected target did not surface Strike board-click intent: %s." % melee_click_intent)
		get_tree().quit(1)
		return false
	var melee_target_context := BattleRules.describe_target_context(session).to_lower()
	if "board click will strike" not in melee_target_context:
		push_error("Core systems smoke: adjacent melee target context did not preview Strike board-click intent: %s." % melee_target_context)
		get_tree().quit(1)
		return false

	var player_ranged := _first_stack_for_side(session.battle, "player", true)
	if player_ranged.is_empty():
		push_error("Core systems smoke: board-click intent coverage could not find a player ranged stack.")
		get_tree().quit(1)
		return false
	var player_ranged_id := String(player_ranged.get("battle_id", ""))
	_set_stack_hex_for_test(session.battle, player_ranged_id, {"q": 4, "r": 2})
	_set_stack_hex_for_test(session.battle, enemy_id, {"q": 5, "r": 2})
	_force_battle_turn(session.battle, player_ranged_id, enemy_id, enemy_id)
	BattleRules.normalize_battle_state(session)
	var ranged_click_intent: Dictionary = BattleRules.selected_target_board_click_intent(session.battle)
	if String(ranged_click_intent.get("action", "")) != "shoot" or String(ranged_click_intent.get("label", "")) != "Shoot":
		push_error("Core systems smoke: legal ranged selected target did not surface Shoot board-click intent: %s." % ranged_click_intent)
		get_tree().quit(1)
		return false
	var ranged_target_context := BattleRules.describe_target_context(session).to_lower()
	if "board click will shoot" not in ranged_target_context:
		push_error("Core systems smoke: ranged target context did not preview Shoot board-click intent: %s." % ranged_target_context)
		get_tree().quit(1)
		return false

	_set_stack_hex_for_test(session.battle, enemy_id, {"q": 8, "r": 3})
	session.battle["distance"] = 0
	_force_battle_turn(session.battle, player_id, enemy_id, enemy_id)
	BattleRules.normalize_battle_state(session)
	if bool(BattleRules.action_availability(session.battle).get("strike", false)):
		push_error("Core systems smoke: non-adjacent hexes still allowed a melee strike.")
		get_tree().quit(1)
		return false
	var blocked_legality: Dictionary = BattleRules.selected_target_legality(session.battle)
	if bool(blocked_legality.get("attackable", false)) or not bool(blocked_legality.get("blocked", false)):
		push_error("Core systems smoke: non-adjacent selected target was not surfaced as blocked: %s." % blocked_legality)
		get_tree().quit(1)
		return false
	var blocked_click_intent: Dictionary = BattleRules.selected_target_board_click_intent(session.battle)
	if String(blocked_click_intent.get("action", "")) != "" or not bool(blocked_click_intent.get("blocked", false)):
		push_error("Core systems smoke: blocked selected target exposed an executable board-click intent: %s." % blocked_click_intent)
		get_tree().quit(1)
		return false
	if not bool(BattleRules.action_availability(session.battle).get("advance", false)):
		push_error("Core systems smoke: engaged non-adjacent stacks did not expose legal repositioning.")
		get_tree().quit(1)
		return false

	var legal_enemy_id := "test_legal_enemy_target"
	_ensure_enemy_stack_for_test(session.battle, enemy_melee, legal_enemy_id)
	_set_stack_hex_for_test(session.battle, player_id, {"q": 4, "r": 3})
	_set_stack_hex_for_test(session.battle, legal_enemy_id, {"q": 5, "r": 3})
	_set_stack_hex_for_test(session.battle, enemy_id, {"q": 8, "r": 3})
	session.battle["distance"] = 0
	_force_battle_turn(session.battle, player_id, enemy_id, legal_enemy_id)
	BattleRules.normalize_battle_state(session)
	session.battle["selected_target_id"] = enemy_id
	var legal_target_ids: Array = BattleRules.legal_attack_target_ids_for_active_stack(session.battle)
	if legal_enemy_id not in legal_target_ids or enemy_id in legal_target_ids:
		push_error("Core systems smoke: legal target ids did not separate reachable and blocked enemies: legal=%s blocked=%s all=%s." % [legal_enemy_id, enemy_id, legal_target_ids])
		get_tree().quit(1)
		return false
	var blocked_target_context := BattleRules.describe_target_context(session).to_lower()
	if "selected target blocked" not in blocked_target_context or "highlighted enemy" not in blocked_target_context or "green hex click" not in blocked_target_context:
		push_error("Core systems smoke: blocked selected target context was not explicit: %s." % blocked_target_context)
		get_tree().quit(1)
		return false
	blocked_click_intent = BattleRules.selected_target_board_click_intent(session.battle)
	var blocked_intent_message := String(blocked_click_intent.get("message", "")).to_lower()
	if "board click blocked" not in blocked_intent_message or "highlighted enemy" not in blocked_intent_message:
		push_error("Core systems smoke: blocked selected target board-click intent was not explicit: %s." % blocked_click_intent)
		get_tree().quit(1)
		return false
	var blocked_action_surface: Dictionary = BattleRules.get_action_surface(session)
	var strike_summary := String(blocked_action_surface.get("strike", {}).get("summary", "")).to_lower()
	if "blocked" not in strike_summary or "highlighted enemy" not in strike_summary or "green hex click" not in strike_summary:
		push_error("Core systems smoke: blocked selected target strike guidance was not explicit: %s." % strike_summary)
		get_tree().quit(1)
		return false
	var blocked_action_text := BattleRules.describe_action_surface(session).to_lower()
	if "green hex click: move" not in blocked_action_text:
		push_error("Core systems smoke: action context did not expose green-hex Move intent while target was blocked: %s." % blocked_action_text)
		get_tree().quit(1)
		return false
	BattleRules.cycle_target(session, 1)
	if String(BattleRules.get_selected_target(session.battle).get("battle_id", "")) != legal_enemy_id:
		push_error("Core systems smoke: target cycling did not prefer the legal target when a blocked target was selected: %s." % session.battle.get("selected_target_id", ""))
		get_tree().quit(1)
		return false
	_remove_battle_stack_for_test(session.battle, legal_enemy_id)
	_force_battle_turn(session.battle, player_id, enemy_id, enemy_id)
	BattleRules.normalize_battle_state(session)
	session.battle["selected_target_id"] = enemy_id

	var out_of_bounds_move := BattleRules.move_active_stack_to_hex(session, -1, 3)
	if bool(out_of_bounds_move.get("ok", false)):
		push_error("Core systems smoke: out-of-bounds hex movement was accepted.")
		get_tree().quit(1)
		return false

	var occupied_move := BattleRules.move_active_stack_to_hex(session, 8, 3)
	if bool(occupied_move.get("ok", false)):
		push_error("Core systems smoke: movement into an occupied hex was accepted.")
		get_tree().quit(1)
		return false

	var legal_destinations: Array = BattleRules.legal_destinations_for_active_stack(session.battle)
	if legal_destinations.is_empty():
		push_error("Core systems smoke: active stack had no legal hex destinations on an open board.")
		get_tree().quit(1)
		return false
	var setup_case := _stage_later_attack_destination_for_test(session.battle, player_id, enemy_id)
	if setup_case.is_empty():
		push_error("Core systems smoke: could not stage a green-hex destination that truthfully sets up a later attack.")
		get_tree().quit(1)
		return false
	var destination: Dictionary = setup_case.get("destination", {})
	var movement_intent: Dictionary = setup_case.get("intent", {})
	var movement_message := String(movement_intent.get("message", "")).to_lower()
	if String(movement_intent.get("action", "")) != "move" or String(movement_intent.get("label", "")) != "Move" or "green hex click: move" not in movement_message:
		push_error("Core systems smoke: legal movement destination did not expose Move board-click intent: %s." % movement_intent)
		get_tree().quit(1)
		return false
	var expected_destination_label := "hex %d,%d" % [int(destination.get("q", -1)), int(destination.get("r", -1))]
	var destination_detail := String(movement_intent.get("destination_detail", "")).to_lower()
	if expected_destination_label not in destination_detail or "step" not in destination_detail:
		push_error("Core systems smoke: movement intent did not expose exact destination detail: destination=%s intent=%s." % [destination, movement_intent])
		get_tree().quit(1)
		return false
	if int(movement_intent.get("steps", -1)) != int(destination.get("steps", -2)) or int(movement_intent.get("steps", 0)) <= 0:
		push_error("Core systems smoke: movement intent step count did not match the legal destination: destination=%s intent=%s." % [destination, movement_intent])
		get_tree().quit(1)
		return false
	if not bool(movement_intent.get("sets_up_selected_target_attack", false)) or String(movement_intent.get("selected_target_setup_label", "")) != "Strike" or "later strike" not in movement_message:
		push_error("Core systems smoke: movement intent did not truthfully surface later-attack setup on the blocked target: %s." % movement_intent)
		get_tree().quit(1)
		return false
	var hex_state: Dictionary = BattleRules.battle_hex_state_summary(session.battle)
	var active_movement_intent: Dictionary = hex_state.get("active_movement_board_click_intent", {})
	if String(active_movement_intent.get("action", "")) != "move" or String(active_movement_intent.get("label", "")) != "Move":
		push_error("Core systems smoke: hex state did not expose active movement board-click intent: %s." % hex_state)
		get_tree().quit(1)
		return false
	var legal_movement_intents: Array = hex_state.get("legal_movement_intents", [])
	var refreshed_legal_destinations: Array = BattleRules.legal_destinations_for_active_stack(session.battle)
	if legal_movement_intents.size() != refreshed_legal_destinations.size():
		push_error("Core systems smoke: movement intent count did not match legal destinations: intents=%s destinations=%s." % [legal_movement_intents, refreshed_legal_destinations])
		get_tree().quit(1)
		return false
	var move_result := BattleRules.move_active_stack_to_hex(
		session,
		int(destination.get("q", -1)),
		int(destination.get("r", -1))
	)
	if not bool(move_result.get("ok", false)):
		push_error("Core systems smoke: legal hex movement was rejected: %s." % move_result)
		get_tree().quit(1)
		return false
	var move_result_message := String(move_result.get("message", ""))
	if not move_result_message.begins_with(String(movement_intent.get("message", ""))):
		push_error("Core systems smoke: clicked move did not preserve the preview movement language: preview=%s result=%s." % [movement_intent, move_result])
		get_tree().quit(1)
		return false
	if String(move_result.get("preview_message", "")) != String(movement_intent.get("message", "")):
		push_error("Core systems smoke: clicked move validation result did not retain the preview message: preview=%s result=%s." % [movement_intent, move_result])
		get_tree().quit(1)
		return false
	if String(move_result.get("destination_detail", "")) != String(movement_intent.get("destination_detail", "")) or int(move_result.get("steps", -1)) != int(movement_intent.get("steps", -2)):
		push_error("Core systems smoke: clicked move result did not retain destination detail/steps: preview=%s result=%s." % [movement_intent, move_result])
		get_tree().quit(1)
		return false
	if bool(move_result.get("sets_up_selected_target_attack", false)) != bool(movement_intent.get("sets_up_selected_target_attack", false)) or String(move_result.get("selected_target_setup_label", "")) != String(movement_intent.get("selected_target_setup_label", "")):
		push_error("Core systems smoke: clicked move result did not retain the later-attack setup hint: preview=%s result=%s." % [movement_intent, move_result])
		get_tree().quit(1)
		return false
	var moved_stack := _battle_stack_by_id(session.battle, player_id)
	if _hex_key_for_test(_stack_hex_for_test(moved_stack)) != _hex_key_for_test(destination):
		push_error("Core systems smoke: legal movement did not update the stack hex.")
		get_tree().quit(1)
		return false
	var restored = _clone_session(session)
	var restored_stack := _battle_stack_by_id(restored.battle, player_id)
	if _hex_key_for_test(_stack_hex_for_test(restored_stack)) != _hex_key_for_test(destination):
		push_error("Core systems smoke: saved battle hex state did not survive restore normalization.")
		get_tree().quit(1)
		return false
	return true

func _run_battle_setup_move_target_continuity_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Core systems smoke: setup-move target continuity coverage could not find a battle encounter.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Core systems smoke: setup-move target continuity coverage could not create a battle payload.")
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(session)

	var player_melee := _first_stack_for_side(session.battle, "player", false)
	var default_enemy := _first_stack_for_side(session.battle, "enemy", false)
	if player_melee.is_empty() or default_enemy.is_empty():
		push_error("Core systems smoke: setup-move target continuity coverage could not find opposing melee stacks.")
		get_tree().quit(1)
		return false

	var player_id := String(player_melee.get("battle_id", ""))
	var default_enemy_id := String(default_enemy.get("battle_id", ""))
	var continuity_target_id := "setup_move_continuity_target"
	_ensure_enemy_stack_for_test(session.battle, default_enemy, continuity_target_id)
	_set_stack_hex_for_test(session.battle, player_id, {"q": 4, "r": 3})
	_set_stack_hex_for_test(session.battle, default_enemy_id, {"q": 5, "r": 3})
	_set_stack_health_for_test(session.battle, player_id, 999)
	session.battle["distance"] = 0
	session.battle["turn_order"] = [player_id, default_enemy_id, continuity_target_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = player_id
	session.battle["selected_target_id"] = continuity_target_id
	BattleRules.normalize_battle_state(session)
	session.battle["selected_target_id"] = continuity_target_id

	var setup_case := _stage_later_attack_destination_for_test(session.battle, player_id, continuity_target_id)
	if setup_case.is_empty():
		push_error("Core systems smoke: setup-move target continuity coverage could not stage a later-attack destination.")
		get_tree().quit(1)
		return false
	var destination: Dictionary = setup_case.get("destination", {})
	var blocked_setup_intent: Dictionary = setup_case.get("intent", {})
	var target_hex: Dictionary = setup_case.get("target_hex", {})
	var default_enemy_hex := _open_neighbor_for_test(session.battle, destination, [_hex_key_for_test(target_hex)])
	if default_enemy_hex.is_empty():
		push_error("Core systems smoke: setup-move target continuity coverage could not place a default legal target near the destination.")
		get_tree().quit(1)
		return false
	_set_stack_hex_for_test(session.battle, default_enemy_id, default_enemy_hex)
	session.battle["selected_target_id"] = continuity_target_id
	var movement_intent := BattleRules.movement_intent_for_destination(
		session.battle,
		int(destination.get("q", -1)),
		int(destination.get("r", -1))
	)
	if not bool(movement_intent.get("sets_up_selected_target_attack", false)):
		push_error("Core systems smoke: setup-move target continuity coverage lost the later-attack setup after adding a default legal target: before=%s after=%s." % [blocked_setup_intent, movement_intent])
		get_tree().quit(1)
		return false
	var pre_move_legality: Dictionary = BattleRules.selected_target_legality(session.battle)
	if not bool(pre_move_legality.get("blocked", false)):
		push_error("Core systems smoke: setup-move target continuity setup did not keep the continuity target blocked before movement: %s." % [pre_move_legality])
		get_tree().quit(1)
		return false

	var move_result := BattleRules.move_active_stack_to_hex(
		session,
		int(destination.get("q", -1)),
		int(destination.get("r", -1))
	)
	if not bool(move_result.get("ok", false)):
		push_error("Core systems smoke: setup-move target continuity move was rejected: %s." % move_result)
		get_tree().quit(1)
		return false
	if not bool(move_result.get("selected_target_continuity_preserved", false)):
		push_error("Core systems smoke: setup-move target continuity was not marked preserved: %s." % move_result)
		get_tree().quit(1)
		return false
	var selected_after_id := String(BattleRules.get_selected_target(session.battle).get("battle_id", ""))
	if selected_after_id != continuity_target_id:
		push_error("Core systems smoke: setup move did not keep the selected blocked target after resolving. expected=%s actual=%s result=%s." % [continuity_target_id, selected_after_id, move_result])
		get_tree().quit(1)
		return false
	if String(move_result.get("selected_target_after_move_battle_id", "")) != continuity_target_id:
		push_error("Core systems smoke: setup-move result did not report the preserved selected target: %s." % move_result)
		get_tree().quit(1)
		return false
	var post_legality: Dictionary = BattleRules.selected_target_legality(session.battle)
	var post_move_legal_targets: Array = BattleRules.legal_attack_target_ids_for_active_stack(session.battle)
	if default_enemy_id not in post_move_legal_targets:
		push_error("Core systems smoke: setup-move target continuity did not retain the competing legal default target after movement: legal=%s result=%s." % [post_move_legal_targets, move_result])
		get_tree().quit(1)
		return false
	var result_legality: Dictionary = move_result.get("selected_target_after_move_legality", {})
	if bool(result_legality.get("attackable", false)) != bool(post_legality.get("attackable", false)) or bool(result_legality.get("blocked", false)) != bool(post_legality.get("blocked", false)):
		push_error("Core systems smoke: setup-move result legality did not match the post-move battle state: result=%s state=%s." % [result_legality, post_legality])
		get_tree().quit(1)
		return false
	var post_click_intent: Dictionary = BattleRules.selected_target_board_click_intent(session.battle)
	var continuity_context: Dictionary = BattleRules.selected_target_continuity_context(session.battle)
	if continuity_context.is_empty() or not bool(continuity_context.get("preserved_setup_target", false)):
		push_error("Core systems smoke: setup-move target continuity did not expose preserved setup context after movement: result=%s context=%s." % [move_result, continuity_context])
		get_tree().quit(1)
		return false
	var post_guidance := BattleRules.describe_target_context(session).to_lower()
	var post_action_guidance := BattleRules.describe_action_surface(session).to_lower()
	if "preserved setup target" not in post_action_guidance:
		push_error("Core systems smoke: setup-move action surface did not call out the preserved setup target: %s." % post_action_guidance)
		get_tree().quit(1)
		return false
	if bool(post_legality.get("attackable", false)):
		var post_action_id := String(post_click_intent.get("action", ""))
		var post_action_surface: Dictionary = BattleRules.get_action_surface(session)
		var surfaced_action: Dictionary = post_action_surface.get(post_action_id, {})
		if (
			post_action_id not in ["strike", "shoot"]
			or "board click will" not in post_guidance
			or "board click will" not in post_action_guidance
			or surfaced_action.is_empty()
			or bool(surfaced_action.get("disabled", true))
		):
			push_error("Core systems smoke: setup-move post guidance did not expose the legal attack truthfully: legality=%s intent=%s guidance=%s." % [post_legality, post_click_intent, post_guidance])
			get_tree().quit(1)
			return false
	elif bool(post_legality.get("blocked", false)):
		if not bool(post_click_intent.get("blocked", false)) or "still blocked" not in post_guidance or "still blocked" not in post_action_guidance:
			push_error("Core systems smoke: setup-move post guidance did not expose the still-blocked truthfully: legality=%s intent=%s guidance=%s." % [post_legality, post_click_intent, post_guidance])
			get_tree().quit(1)
			return false
	else:
		push_error("Core systems smoke: setup-move post legality was neither attackable nor blocked: %s." % post_legality)
		get_tree().quit(1)
		return false
	if String(move_result.get("selected_target_after_move_board_click_action", "")) != String(post_click_intent.get("action", "")):
		push_error("Core systems smoke: setup-move result did not report the same post-move board-click action as the battle state: result=%s state=%s." % [move_result, post_click_intent])
		get_tree().quit(1)
		return false
	BattleRules.cycle_target(session, 1)
	var retargeted_id := String(BattleRules.get_selected_target(session.battle).get("battle_id", ""))
	if retargeted_id == "" or retargeted_id == continuity_target_id:
		push_error("Core systems smoke: setup-move retarget cycle did not move focus away from the preserved setup target. selected=%s preserved=%s." % [retargeted_id, continuity_target_id])
		get_tree().quit(1)
		return false
	var retarget_context: Dictionary = BattleRules.selected_target_continuity_context(session.battle)
	var retarget_guidance := BattleRules.describe_target_context(session).to_lower()
	var retarget_action_guidance := BattleRules.describe_action_surface(session).to_lower()
	if session.battle.has(BattleRules.SELECTED_TARGET_CONTINUITY_KEY) or not retarget_context.is_empty() or "preserved setup target" in retarget_guidance or "preserved setup target" in retarget_action_guidance:
		push_error("Core systems smoke: explicit target cycling left preserved setup context stuck on the old target: selected=%s context=%s target=%s action=%s battle=%s." % [retargeted_id, retarget_context, retarget_guidance, retarget_action_guidance, session.battle])
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(session)
	var normalized_id := String(BattleRules.get_selected_target(session.battle).get("battle_id", ""))
	if normalized_id == continuity_target_id or not BattleRules.selected_target_continuity_context(session.battle).is_empty():
		push_error("Core systems smoke: cleared setup-target continuity reasserted after battle normalization: selected=%s preserved=%s battle=%s." % [normalized_id, continuity_target_id, session.battle])
		get_tree().quit(1)
		return false
	var active_after_clear := BattleRules.get_active_stack(session.battle)
	var refocus_hex := _open_neighbor_for_test(session.battle, _stack_hex_for_test(active_after_clear))
	if refocus_hex.is_empty():
		push_error("Core systems smoke: cleared setup-target continuity coverage could not place the old target for cycle-back proof.")
		get_tree().quit(1)
		return false
	_set_stack_hex_for_test(session.battle, continuity_target_id, refocus_hex)
	BattleRules.select_target(session, retargeted_id)
	var cycled_back_id := ""
	for _attempt in range(4):
		BattleRules.cycle_target(session, 1)
		cycled_back_id = String(BattleRules.get_selected_target(session.battle).get("battle_id", ""))
		if cycled_back_id == continuity_target_id:
			break
	var cycled_back_context: Dictionary = BattleRules.selected_target_continuity_context(session.battle)
	var cycled_back_guidance := BattleRules.describe_target_context(session).to_lower()
	var cycled_back_action_guidance := BattleRules.describe_action_surface(session).to_lower()
	if (
		cycled_back_id != continuity_target_id
		or session.battle.has(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
		or not cycled_back_context.is_empty()
		or "preserved setup target" in cycled_back_guidance
		or "preserved setup target" in cycled_back_action_guidance
	):
		push_error("Core systems smoke: cycling back to the old setup target resurrected preserved context or failed to refocus it normally: selected=%s context=%s target=%s action=%s battle=%s." % [cycled_back_id, cycled_back_context, cycled_back_guidance, cycled_back_action_guidance, session.battle])
		get_tree().quit(1)
		return false
	var reselect_other := BattleRules.select_target(session, retargeted_id)
	if not bool(reselect_other.get("ok", false)):
		push_error("Core systems smoke: cleared setup-target continuity coverage could not reselect the replacement target: %s." % reselect_other)
		get_tree().quit(1)
		return false
	var old_target_selection := BattleRules.select_target(session, continuity_target_id)
	var old_target_selection_context: Dictionary = BattleRules.selected_target_continuity_context(session.battle)
	var old_target_selection_result_context: Dictionary = old_target_selection.get("selected_target_continuity_context", {}) if old_target_selection.get("selected_target_continuity_context", {}) is Dictionary else {}
	var old_target_selection_guidance := BattleRules.describe_target_context(session).to_lower()
	var old_target_selection_action_guidance := BattleRules.describe_action_surface(session).to_lower()
	if (
		not bool(old_target_selection.get("ok", false))
		or bool(old_target_selection.get("selected_target_preserved_setup", false))
		or session.battle.has(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
		or not old_target_selection_context.is_empty()
		or not old_target_selection_result_context.is_empty()
		or "preserved setup target" in old_target_selection_guidance
		or "preserved setup target" in old_target_selection_action_guidance
	):
		push_error("Core systems smoke: selecting back to the old setup target resurrected preserved context instead of normal target focus: result=%s context=%s target=%s action=%s battle=%s." % [old_target_selection, old_target_selection_context, old_target_selection_guidance, old_target_selection_action_guidance, session.battle])
		get_tree().quit(1)
		return false
	var followup_player_id := "post_clear_normal_move_player"
	_ensure_player_stack_for_test(session.battle, active_after_clear, followup_player_id)
	_remove_battle_stack_for_test(session.battle, retargeted_id)
	for enemy_id in _enemy_stack_ids_except_for_test(session.battle, continuity_target_id):
		_remove_battle_stack_for_test(session.battle, enemy_id)
	var alternate_enemy_id := "ordinary_closing_retarget_enemy"
	_ensure_enemy_stack_for_test(session.battle, _battle_stack_by_id(session.battle, continuity_target_id), alternate_enemy_id)
	_set_stack_combat_profile_for_test(session.battle, player_id, 1, false, [])
	_set_stack_combat_profile_for_test(session.battle, followup_player_id, 1, false, [])
	_set_stack_health_for_test(session.battle, player_id, 999)
	_set_stack_health_for_test(session.battle, followup_player_id, 999)
	_set_stack_hex_for_test(session.battle, player_id, {"q": 0, "r": 3})
	_set_stack_hex_for_test(session.battle, followup_player_id, {"q": 0, "r": 0})
	_set_stack_hex_for_test(session.battle, continuity_target_id, {"q": 4, "r": 3})
	_set_stack_hex_for_test(session.battle, alternate_enemy_id, {"q": 10, "r": 6})
	session.battle.erase(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
	session.battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)
	session.battle["turn_order"] = [player_id, player_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = player_id
	session.battle["selected_target_id"] = continuity_target_id
	var normal_move_intent := BattleRules.movement_intent_for_destination(session.battle, 1, 3)
	if (
		String(normal_move_intent.get("action", "")) != "move"
		or not bool(normal_move_intent.get("closes_on_selected_target", false))
		or bool(normal_move_intent.get("sets_up_selected_target_attack", false))
		or String(normal_move_intent.get("selected_target_battle_id", "")) != continuity_target_id
	):
		push_error("Core systems smoke: post-clear old-target normal movement setup was not a non-continuity move toward the target: %s battle=%s." % [normal_move_intent, session.battle])
		get_tree().quit(1)
		return false
	var normal_move_result := BattleRules.move_active_stack_to_hex(session, 1, 3)
	var normal_result_context: Dictionary = normal_move_result.get("selected_target_continuity_context", {}) if normal_move_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var normal_closing_context: Dictionary = normal_move_result.get("selected_target_closing_context", {}) if normal_move_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var normal_state_context: Dictionary = BattleRules.selected_target_continuity_context(session.battle)
	var normal_state_closing_context: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	var normal_post_guidance := String(normal_move_result.get("post_move_target_guidance", "")).to_lower()
	var normal_target_guidance := BattleRules.describe_target_context(session).to_lower()
	var normal_action_guidance := BattleRules.describe_action_surface(session).to_lower()
	var normal_click_intent: Dictionary = BattleRules.selected_target_board_click_intent(session.battle)
	if (
		not bool(normal_move_result.get("ok", false))
		or bool(normal_move_result.get("selected_target_continuity_preserved", false))
		or session.battle.has(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
		or not normal_result_context.is_empty()
		or not normal_state_context.is_empty()
		or String(normal_move_result.get("selected_target_after_move_battle_id", "")) != continuity_target_id
		or not bool(normal_click_intent.get("blocked", false))
		or not bool(normal_move_result.get("closes_on_selected_target", false))
		or not bool(normal_move_result.get("selected_target_closing_on_target", false))
		or normal_closing_context.is_empty()
		or not bool(normal_closing_context.get("ordinary_closing_target", false))
		or bool(normal_closing_context.get("preserved_setup_target", false))
		or normal_state_closing_context.is_empty()
		or String(normal_state_closing_context.get("battle_id", "")) != continuity_target_id
		or "closing on target" not in normal_post_guidance
		or "closing on target" not in normal_target_guidance
		or "closing on target" not in normal_action_guidance
		or "preserved setup target" in normal_post_guidance
		or "preserved setup target" in normal_target_guidance
		or "preserved setup target" in normal_action_guidance
	):
		push_error("Core systems smoke: post-clear normal movement toward the old setup target did not stay ordinary while surfacing closing progress: intent=%s result=%s continuity=%s closing=%s target=%s action=%s battle=%s." % [normal_move_intent, normal_move_result, normal_state_context, normal_state_closing_context, normal_target_guidance, normal_action_guidance, session.battle])
		get_tree().quit(1)
		return false

	_set_stack_hex_for_test(session.battle, continuity_target_id, {"q": 2, "r": 3})
	var attackable_closing_context: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	var attackable_legality: Dictionary = BattleRules.selected_target_legality(session.battle)
	var attackable_click_intent: Dictionary = BattleRules.selected_target_board_click_intent(session.battle)
	var attackable_action_surface: Dictionary = BattleRules.get_action_surface(session)
	var attackable_action_id := String(attackable_click_intent.get("action", ""))
	var attackable_action: Dictionary = attackable_action_surface.get(attackable_action_id, {}) if attackable_action_surface.get(attackable_action_id, {}) is Dictionary else {}
	var attackable_target_guidance := BattleRules.describe_target_context(session).to_lower()
	var attackable_action_guidance := BattleRules.describe_action_surface(session).to_lower()
	var attackable_hex_summary: Dictionary = BattleRules.battle_hex_state_summary(session.battle)
	var attackable_summary_closing: Dictionary = attackable_hex_summary.get("selected_target_closing_context", {}) if attackable_hex_summary.get("selected_target_closing_context", {}) is Dictionary else {}
	if (
		session.battle.has(BattleRules.SELECTED_TARGET_CLOSING_KEY)
		or not attackable_closing_context.is_empty()
		or not attackable_summary_closing.is_empty()
		or not bool(attackable_legality.get("attackable", false))
		or attackable_action_id not in ["strike", "shoot"]
		or attackable_action.is_empty()
		or bool(attackable_action.get("disabled", true))
		or "closing on target" in attackable_target_guidance
		or "closing on target" in attackable_action_guidance
		or "board click will" not in attackable_target_guidance
		or "board click will" not in attackable_action_guidance
	):
		push_error("Core systems smoke: ordinary closing context did not clear when the selected target became attackable: closing=%s legality=%s intent=%s target=%s action=%s summary=%s battle=%s." % [attackable_closing_context, attackable_legality, attackable_click_intent, attackable_target_guidance, attackable_action_guidance, attackable_hex_summary, session.battle])
		get_tree().quit(1)
		return false

	_set_stack_hex_for_test(session.battle, player_id, {"q": 0, "r": 3})
	_set_stack_hex_for_test(session.battle, continuity_target_id, {"q": 4, "r": 3})
	_set_stack_hex_for_test(session.battle, alternate_enemy_id, {"q": 10, "r": 6})
	session.battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)
	session.battle["turn_order"] = [player_id, player_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = player_id
	session.battle["selected_target_id"] = continuity_target_id
	var retarget_stage_result := BattleRules.move_active_stack_to_hex(session, 1, 3)
	var retarget_stage_context := BattleRules.selected_target_closing_context(session.battle)
	if not bool(retarget_stage_result.get("ok", false)) or retarget_stage_context.is_empty():
		push_error("Core systems smoke: ordinary closing retarget-clear setup did not recreate closing context: result=%s context=%s battle=%s." % [retarget_stage_result, retarget_stage_context, session.battle])
		get_tree().quit(1)
		return false
	var closing_retarget_result := BattleRules.select_target(session, alternate_enemy_id)
	var retarget_closing_context: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	var retarget_action_guidance_after_closing := BattleRules.describe_action_surface(session).to_lower()
	var retarget_target_guidance_after_closing := BattleRules.describe_target_context(session).to_lower()
	var retarget_result_closing: Dictionary = closing_retarget_result.get("selected_target_closing_context", {}) if closing_retarget_result.get("selected_target_closing_context", {}) is Dictionary else {}
	if (
		not bool(closing_retarget_result.get("ok", false))
		or session.battle.has(BattleRules.SELECTED_TARGET_CLOSING_KEY)
		or bool(closing_retarget_result.get("selected_target_closing_on_target", false))
		or not retarget_result_closing.is_empty()
		or not retarget_closing_context.is_empty()
		or "closing on target" in retarget_action_guidance_after_closing
		or "closing on target" in retarget_target_guidance_after_closing
	):
		push_error("Core systems smoke: ordinary closing context did not clear when selected target changed: result=%s context=%s target=%s action=%s battle=%s." % [closing_retarget_result, retarget_closing_context, retarget_target_guidance_after_closing, retarget_action_guidance_after_closing, session.battle])
		get_tree().quit(1)
		return false

	_set_stack_hex_for_test(session.battle, player_id, {"q": 0, "r": 3})
	_set_stack_hex_for_test(session.battle, followup_player_id, {"q": 0, "r": 0})
	_set_stack_hex_for_test(session.battle, continuity_target_id, {"q": 4, "r": 3})
	session.battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)
	session.battle["turn_order"] = [player_id, player_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = player_id
	session.battle["selected_target_id"] = continuity_target_id
	var active_change_stage_result := BattleRules.move_active_stack_to_hex(session, 1, 3)
	var active_change_stage_context := BattleRules.selected_target_closing_context(session.battle)
	if not bool(active_change_stage_result.get("ok", false)) or active_change_stage_context.is_empty():
		push_error("Core systems smoke: ordinary closing active-change setup did not recreate closing context: result=%s context=%s battle=%s." % [active_change_stage_result, active_change_stage_context, session.battle])
		get_tree().quit(1)
		return false
	session.battle["turn_order"] = [followup_player_id, followup_player_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = followup_player_id
	var active_changed_closing_context: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	var active_changed_target_guidance := BattleRules.describe_target_context(session).to_lower()
	var active_changed_action_guidance := BattleRules.describe_action_surface(session).to_lower()
	if (
		session.battle.has(BattleRules.SELECTED_TARGET_CLOSING_KEY)
		or not active_changed_closing_context.is_empty()
		or "closing on target" in active_changed_target_guidance
		or "closing on target" in active_changed_action_guidance
	):
		push_error("Core systems smoke: ordinary closing context did not clear after active stack changed: context=%s target=%s action=%s battle=%s." % [active_changed_closing_context, active_changed_target_guidance, active_changed_action_guidance, session.battle])
		get_tree().quit(1)
		return false

	session.battle["selected_target_id"] = continuity_target_id
	var fresh_setup_case := _stage_later_attack_destination_for_test(session.battle, followup_player_id, continuity_target_id)
	if fresh_setup_case.is_empty():
		push_error("Core systems smoke: post-clear fresh setup coverage could not stage a new setup move for the old target.")
		get_tree().quit(1)
		return false
	var fresh_destination: Dictionary = fresh_setup_case.get("destination", {})
	var fresh_intent := BattleRules.movement_intent_for_destination(
		session.battle,
		int(fresh_destination.get("q", -1)),
		int(fresh_destination.get("r", -1))
	)
	if not bool(fresh_intent.get("sets_up_selected_target_attack", false)):
		push_error("Core systems smoke: post-clear fresh setup move did not truthfully preview recreated continuity: %s." % fresh_intent)
		get_tree().quit(1)
		return false
	var fresh_result := BattleRules.move_active_stack_to_hex(
		session,
		int(fresh_destination.get("q", -1)),
		int(fresh_destination.get("r", -1))
	)
	var fresh_context: Dictionary = BattleRules.selected_target_continuity_context(session.battle)
	if (
		not bool(fresh_result.get("ok", false))
		or not bool(fresh_result.get("selected_target_continuity_preserved", false))
		or bool(fresh_result.get("selected_target_closing_on_target", false))
		or not BattleRules.selected_target_closing_context(session.battle).is_empty()
		or fresh_context.is_empty()
		or not bool(fresh_context.get("preserved_setup_target", false))
		or String(fresh_context.get("battle_id", "")) != continuity_target_id
	):
		push_error("Core systems smoke: fresh setup move after retarget clear did not recreate preserved setup continuity: intent=%s result=%s context=%s battle=%s." % [fresh_intent, fresh_result, fresh_context, session.battle])
		get_tree().quit(1)
		return false
	return true

func _run_battle_direct_actionable_after_move_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Core systems smoke: direct actionable move coverage could not find a battle encounter.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Core systems smoke: direct actionable move coverage could not create a battle payload.")
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(session)

	var player_melee := _first_stack_for_side(session.battle, "player", false)
	var selected_enemy := _first_stack_for_side(session.battle, "enemy", false)
	if player_melee.is_empty() or selected_enemy.is_empty():
		push_error("Core systems smoke: direct actionable move coverage could not find opposing melee stacks.")
		get_tree().quit(1)
		return false

	var player_id := String(player_melee.get("battle_id", ""))
	var target_id := String(selected_enemy.get("battle_id", ""))
	for enemy_id in _enemy_stack_ids_except_for_test(session.battle, target_id):
		_remove_battle_stack_for_test(session.battle, enemy_id)
	_set_stack_combat_profile_for_test(session.battle, player_id, 1, false, [])
	_set_stack_health_for_test(session.battle, player_id, 999)
	_set_stack_health_for_test(session.battle, target_id, 999)
	_set_stack_hex_for_test(session.battle, player_id, {"q": 0, "r": 3})
	_set_stack_hex_for_test(session.battle, target_id, {"q": 3, "r": 3})
	session.battle["distance"] = 0
	session.battle["turn_order"] = [player_id, player_id, player_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = player_id
	session.battle["selected_target_id"] = target_id
	session.battle.erase(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
	session.battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)

	var first_intent := BattleRules.movement_intent_for_destination(session.battle, 1, 3)
	if (
		String(first_intent.get("action", "")) != "move"
		or not bool(first_intent.get("closes_on_selected_target", false))
		or bool(first_intent.get("sets_up_selected_target_attack", false))
	):
		push_error("Core systems smoke: direct actionable move coverage could not stage the ordinary closing lead-in: intent=%s battle=%s." % [first_intent, session.battle])
		get_tree().quit(1)
		return false
	var first_result := BattleRules.move_active_stack_to_hex(session, 1, 3)
	var lead_in_closing_context: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	if (
		not bool(first_result.get("ok", false))
		or lead_in_closing_context.is_empty()
		or not bool(lead_in_closing_context.get("ordinary_closing_target", false))
		or bool(lead_in_closing_context.get("preserved_setup_target", false))
	):
		push_error("Core systems smoke: direct actionable move coverage did not create an ordinary closing lead-in: result=%s context=%s battle=%s." % [first_result, lead_in_closing_context, session.battle])
		get_tree().quit(1)
		return false

	var movement_intent := BattleRules.movement_intent_for_destination(session.battle, 2, 3)
	var pre_legality: Dictionary = BattleRules.selected_target_legality(session.battle)
	if (
		not bool(pre_legality.get("blocked", false))
		or not bool(movement_intent.get("sets_up_selected_target_attack", false))
		or not bool(movement_intent.get("selected_target_after_move_attackable", false))
		or not bool(movement_intent.get("selected_target_closing_before_move", false))
	):
		push_error("Core systems smoke: direct actionable move setup was not an ordinary-closing target that becomes attackable after movement: legality=%s intent=%s battle=%s." % [pre_legality, movement_intent, session.battle])
		get_tree().quit(1)
		return false

	var move_result := BattleRules.move_active_stack_to_hex(session, 2, 3)
	var result_context: Dictionary = move_result.get("selected_target_continuity_context", {}) if move_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var result_closing_context: Dictionary = move_result.get("selected_target_closing_context", {}) if move_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var state_context: Dictionary = BattleRules.selected_target_continuity_context(session.battle)
	var state_closing_context: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	var post_legality: Dictionary = BattleRules.selected_target_legality(session.battle)
	var post_click_intent: Dictionary = BattleRules.selected_target_board_click_intent(session.battle)
	var post_action_id := String(post_click_intent.get("action", ""))
	var post_action_surface: Dictionary = BattleRules.get_action_surface(session)
	var post_action: Dictionary = post_action_surface.get(post_action_id, {}) if post_action_surface.get(post_action_id, {}) is Dictionary else {}
	var post_guidance := String(move_result.get("post_move_target_guidance", "")).to_lower()
	var target_context := BattleRules.describe_target_context(session).to_lower()
	var action_guidance := BattleRules.describe_action_surface(session).to_lower()
	var hex_summary: Dictionary = BattleRules.battle_hex_state_summary(session.battle)
	if (
		not bool(move_result.get("ok", false))
		or String(BattleRules.get_selected_target(session.battle).get("battle_id", "")) != target_id
		or String(move_result.get("selected_target_after_move_battle_id", "")) != target_id
		or not bool(post_legality.get("attackable", false))
		or post_action_id not in ["strike", "shoot"]
		or post_action.is_empty()
		or bool(post_action.get("disabled", true))
		or not bool(move_result.get("selected_target_actionable_after_move", false))
		or not bool(hex_summary.get("selected_target_direct_actionable", false))
		or bool(move_result.get("selected_target_continuity_preserved", false))
		or session.battle.has(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
		or not result_context.is_empty()
		or not state_context.is_empty()
		or bool(move_result.get("selected_target_closing_on_target", false))
		or session.battle.has(BattleRules.SELECTED_TARGET_CLOSING_KEY)
		or not result_closing_context.is_empty()
		or not state_closing_context.is_empty()
		or "board click will" not in post_guidance
		or "board click will" not in target_context
		or "board click will" not in action_guidance
		or "preserved setup target" in post_guidance
		or "preserved setup target" in target_context
		or "preserved setup target" in action_guidance
		or "closing on target" in post_guidance
		or "closing on target" in target_context
		or "closing on target" in action_guidance
	):
		push_error("Core systems smoke: direct actionable move did not surface normal board-click action without setup/closing state: intent=%s result=%s legality=%s click=%s target=%s action=%s summary=%s battle=%s." % [movement_intent, move_result, post_legality, post_click_intent, target_context, action_guidance, hex_summary, session.battle])
		get_tree().quit(1)
		return false

	var health_before_attack := int(_battle_stack_by_id(session.battle, target_id).get("total_health", 0))
	var attack_result := BattleRules.perform_player_action(session, post_action_id)
	var attack_context: Dictionary = attack_result.get("selected_target_continuity_context", {}) if attack_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var attack_closing_context: Dictionary = attack_result.get("selected_target_closing_context", {}) if attack_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var state_context_after_attack: Dictionary = BattleRules.selected_target_continuity_context(session.battle)
	var state_closing_after_attack: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	var selected_after_attack_id := String(BattleRules.get_selected_target(session.battle).get("battle_id", ""))
	var attack_legality: Dictionary = BattleRules.selected_target_legality(session.battle)
	var attack_click_intent: Dictionary = BattleRules.selected_target_board_click_intent(session.battle)
	var attack_hex_summary: Dictionary = BattleRules.battle_hex_state_summary(session.battle)
	var attack_summary_legality: Dictionary = attack_hex_summary.get("selected_target_legality", {}) if attack_hex_summary.get("selected_target_legality", {}) is Dictionary else {}
	var attack_target_context := BattleRules.describe_target_context(session).to_lower()
	var attack_action_guidance := BattleRules.describe_action_surface(session).to_lower()
	if (
		not bool(attack_result.get("ok", false))
		or String(attack_result.get("attack_action", "")) != post_action_id
		or String(attack_result.get("attack_target_battle_id", "")) != target_id
		or int(_battle_stack_by_id(session.battle, target_id).get("total_health", 0)) >= health_before_attack
		or selected_after_attack_id != target_id
		or String(attack_result.get("selected_target_after_attack_battle_id", "")) != target_id
		or not bool(attack_legality.get("attackable", false))
		or String(attack_click_intent.get("action", "")) not in ["strike", "shoot"]
		or bool(attack_result.get("selected_target_preserved_setup", false))
		or not attack_context.is_empty()
		or session.battle.has(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
		or bool(attack_result.get("selected_target_closing_on_target", false))
		or not attack_closing_context.is_empty()
		or session.battle.has(BattleRules.SELECTED_TARGET_CLOSING_KEY)
		or not state_context_after_attack.is_empty()
		or not state_closing_after_attack.is_empty()
		or attack_result.has("selected_target_actionable_after_move")
		or bool(attack_hex_summary.get("selected_target_preserved_setup", false))
		or bool(attack_hex_summary.get("selected_target_closing_on_target", false))
		or not bool(attack_hex_summary.get("selected_target_direct_actionable", false))
		or "board click will" not in attack_target_context
		or "board click will" not in attack_action_guidance
		or "direct actionable after move" in attack_target_context
		or "direct actionable after move" in attack_action_guidance
		or "preserved setup target" in attack_target_context
		or "preserved setup target" in attack_action_guidance
		or "closing on target" in attack_target_context
		or "closing on target" in attack_action_guidance
		):
			push_error("Core systems smoke: immediate board-click attack after direct actionable move left stale transition state or left the normal attack path: attack=%s legality=%s click=%s target=%s action=%s summary=%s battle=%s." % [attack_result, attack_legality, attack_click_intent, attack_target_context, attack_action_guidance, attack_hex_summary, session.battle])
			get_tree().quit(1)
			return false
	return true

func _run_battle_direct_actionable_after_move_invalidation_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Core systems smoke: direct actionable invalidation coverage could not find a battle encounter.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Core systems smoke: direct actionable invalidation coverage could not create a battle payload.")
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(session)

	var player_melee := _first_stack_for_side(session.battle, "player", false)
	var selected_enemy := _first_stack_for_side(session.battle, "enemy", false)
	if player_melee.is_empty() or selected_enemy.is_empty():
		push_error("Core systems smoke: direct actionable invalidation coverage could not find opposing melee stacks.")
		get_tree().quit(1)
		return false

	var player_id := String(player_melee.get("battle_id", ""))
	var target_id := String(selected_enemy.get("battle_id", ""))
	var handoff_target_id := "direct_actionable_after_move_handoff_target"
	for enemy_id in _enemy_stack_ids_except_for_test(session.battle, target_id):
		_remove_battle_stack_for_test(session.battle, enemy_id)
	_ensure_enemy_stack_for_test(session.battle, selected_enemy, handoff_target_id)
	_set_stack_combat_profile_for_test(session.battle, player_id, 1, false, [])
	_set_stack_combat_profile_for_test(session.battle, target_id, 1, false, [])
	_set_stack_combat_profile_for_test(session.battle, handoff_target_id, 1, false, [])
	_set_stack_health_for_test(session.battle, player_id, 999)
	_set_stack_health_for_test(session.battle, target_id, 1)
	_set_stack_health_for_test(session.battle, handoff_target_id, 999)
	_set_stack_hex_for_test(session.battle, player_id, {"q": 0, "r": 3})
	_set_stack_hex_for_test(session.battle, target_id, {"q": 3, "r": 3})
	_set_stack_hex_for_test(session.battle, handoff_target_id, {"q": 5, "r": 3})
	session.battle["distance"] = 0
	session.battle["turn_order"] = [player_id, player_id, player_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = player_id
	session.battle["selected_target_id"] = target_id
	session.battle.erase(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
	session.battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)

	var first_result := BattleRules.move_active_stack_to_hex(session, 1, 3)
	var first_closing: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	if not bool(first_result.get("ok", false)) or first_closing.is_empty() or not bool(first_closing.get("ordinary_closing_target", false)):
		push_error("Core systems smoke: direct actionable invalidation setup did not create the ordinary closing lead-in: result=%s context=%s battle=%s." % [first_result, first_closing, session.battle])
		get_tree().quit(1)
		return false

	var movement_intent := BattleRules.movement_intent_for_destination(session.battle, 2, 3)
	if (
		String(movement_intent.get("action", "")) != "move"
		or not bool(movement_intent.get("selected_target_closing_before_move", false))
		or not bool(movement_intent.get("sets_up_selected_target_attack", false))
		or not bool(movement_intent.get("selected_target_after_move_attackable", false))
	):
		push_error("Core systems smoke: direct actionable invalidation setup did not preview the closing-to-actionable move: intent=%s battle=%s." % [movement_intent, session.battle])
		get_tree().quit(1)
		return false

	var move_result := BattleRules.move_active_stack_to_hex(session, 2, 3)
	var action_id := String(move_result.get("selected_target_after_move_board_click_action", ""))
	if (
		not bool(move_result.get("ok", false))
		or String(move_result.get("selected_target_after_move_battle_id", "")) != target_id
		or action_id not in ["strike", "shoot"]
		or not bool(move_result.get("selected_target_actionable_after_move", false))
		or bool(move_result.get("selected_target_preserved_setup", false))
		or bool(move_result.get("selected_target_closing_on_target", false))
	):
		push_error("Core systems smoke: direct actionable invalidation move did not reach the normal immediate attack state: result=%s battle=%s." % [move_result, session.battle])
		get_tree().quit(1)
		return false

	var attack_result := BattleRules.perform_player_action(session, action_id)
	var selected_after_attack_id := String(BattleRules.get_selected_target(session.battle).get("battle_id", ""))
	var attack_context: Dictionary = attack_result.get("selected_target_continuity_context", {}) if attack_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var attack_closing: Dictionary = attack_result.get("selected_target_closing_context", {}) if attack_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var state_context: Dictionary = BattleRules.selected_target_continuity_context(session.battle)
	var state_closing: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	var attack_legality: Dictionary = BattleRules.selected_target_legality(session.battle)
	var attack_click_intent: Dictionary = BattleRules.selected_target_board_click_intent(session.battle)
	var attack_hex_summary: Dictionary = BattleRules.battle_hex_state_summary(session.battle)
	var attack_summary_legality: Dictionary = attack_hex_summary.get("selected_target_legality", {}) if attack_hex_summary.get("selected_target_legality", {}) is Dictionary else {}
	var attack_target_context := BattleRules.describe_target_context(session).to_lower()
	var attack_action_guidance := BattleRules.describe_action_surface(session).to_lower()
	if (
		not bool(attack_result.get("ok", false))
		or String(attack_result.get("attack_action", "")) != action_id
		or String(attack_result.get("attack_target_battle_id", "")) != target_id
		or int(_battle_stack_by_id(session.battle, target_id).get("total_health", 0)) > 0
		or not bool(attack_result.get("attack_target_invalidated_after_attack", false))
		or bool(attack_result.get("attack_target_still_selected_after_attack", true))
			or bool(attack_result.get("attack_target_alive_after_attack", true))
			or selected_after_attack_id != handoff_target_id
			or String(attack_result.get("selected_target_after_attack_battle_id", "")) != handoff_target_id
			or not bool(attack_result.get("selected_target_valid_after_attack", false))
			or not bool(attack_result.get("selected_target_handoff_after_attack", false))
			or bool(attack_result.get("selected_target_handoff_direct_actionable_after_attack", false))
			or not bool(attack_result.get("selected_target_handoff_blocked_after_attack", false))
			or not bool(attack_legality.get("blocked", false))
			or bool(attack_legality.get("attackable", false))
		or String(attack_click_intent.get("action", "")) != ""
		or bool(attack_result.get("selected_target_direct_actionable_after_attack", false))
		or bool(attack_result.get("selected_target_preserved_setup", false))
		or bool(attack_result.get("selected_target_closing_on_target", false))
		or not attack_context.is_empty()
		or not attack_closing.is_empty()
		or not state_context.is_empty()
		or not state_closing.is_empty()
		or session.battle.has(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
		or session.battle.has(BattleRules.SELECTED_TARGET_CLOSING_KEY)
		or attack_result.has("selected_target_actionable_after_move")
		or attack_result.has("selected_target_after_move_battle_id")
		or bool(attack_hex_summary.get("selected_target_direct_actionable", false))
		or not bool(attack_summary_legality.get("blocked", false))
		or "direct actionable after move" in attack_target_context
		or "direct actionable after move" in attack_action_guidance
		or "preserved setup target" in attack_target_context
		or "preserved setup target" in attack_action_guidance
		or "closing on target" in attack_target_context
		or "closing on target" in attack_action_guidance
	):
		push_error("Core systems smoke: invalidating immediate attack after direct actionable move did not clear transition state or hand off to the normal blocked target: attack=%s legality=%s click=%s target=%s action=%s summary=%s battle=%s." % [attack_result, attack_legality, attack_click_intent, attack_target_context, attack_action_guidance, attack_hex_summary, session.battle])
		get_tree().quit(1)
		return false
	return true

func _run_battle_direct_actionable_after_move_direct_handoff_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Core systems smoke: direct actionable handoff coverage could not find a battle encounter.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Core systems smoke: direct actionable handoff coverage could not create a battle payload.")
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(session)

	var player_melee := _first_stack_for_side(session.battle, "player", false)
	var selected_enemy := _first_stack_for_side(session.battle, "enemy", false)
	if player_melee.is_empty() or selected_enemy.is_empty():
		push_error("Core systems smoke: direct actionable handoff coverage could not find opposing melee stacks.")
		get_tree().quit(1)
		return false

	var player_id := String(player_melee.get("battle_id", ""))
	var target_id := String(selected_enemy.get("battle_id", ""))
	var handoff_target_id := "direct_actionable_after_move_direct_handoff_target"
	for enemy_id in _enemy_stack_ids_except_for_test(session.battle, target_id):
		_remove_battle_stack_for_test(session.battle, enemy_id)
	_ensure_enemy_stack_for_test(session.battle, selected_enemy, handoff_target_id)
	_set_stack_combat_profile_for_test(session.battle, player_id, 1, false, [])
	_set_stack_combat_profile_for_test(session.battle, target_id, 1, false, [])
	_set_stack_combat_profile_for_test(session.battle, handoff_target_id, 1, false, [])
	_set_stack_health_for_test(session.battle, player_id, 999)
	_set_stack_health_for_test(session.battle, target_id, 1)
	_set_stack_health_for_test(session.battle, handoff_target_id, 999)
	_set_stack_hex_for_test(session.battle, player_id, {"q": 0, "r": 3})
	_set_stack_hex_for_test(session.battle, target_id, {"q": 3, "r": 3})
	_set_stack_hex_for_test(session.battle, handoff_target_id, {"q": 3, "r": 2})
	session.battle["distance"] = 0
	session.battle["turn_order"] = [player_id, player_id, player_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = player_id
	session.battle["selected_target_id"] = target_id
	session.battle.erase(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
	session.battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)

	var first_result := BattleRules.move_active_stack_to_hex(session, 1, 3)
	var first_closing: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	if not bool(first_result.get("ok", false)) or first_closing.is_empty() or not bool(first_closing.get("ordinary_closing_target", false)):
		push_error("Core systems smoke: direct actionable handoff setup did not create the ordinary closing lead-in: result=%s context=%s battle=%s." % [first_result, first_closing, session.battle])
		get_tree().quit(1)
		return false

	var movement_intent := BattleRules.movement_intent_for_destination(session.battle, 2, 3)
	if (
		String(movement_intent.get("action", "")) != "move"
		or not bool(movement_intent.get("selected_target_closing_before_move", false))
		or not bool(movement_intent.get("sets_up_selected_target_attack", false))
		or not bool(movement_intent.get("selected_target_after_move_attackable", false))
	):
		push_error("Core systems smoke: direct actionable handoff setup did not preview the closing-to-actionable move: intent=%s battle=%s." % [movement_intent, session.battle])
		get_tree().quit(1)
		return false

	var move_result := BattleRules.move_active_stack_to_hex(session, 2, 3)
	var action_id := String(move_result.get("selected_target_after_move_board_click_action", ""))
	if (
		not bool(move_result.get("ok", false))
		or String(move_result.get("selected_target_after_move_battle_id", "")) != target_id
		or action_id not in ["strike", "shoot"]
		or not bool(move_result.get("selected_target_actionable_after_move", false))
		or bool(move_result.get("selected_target_preserved_setup", false))
		or bool(move_result.get("selected_target_closing_on_target", false))
	):
		push_error("Core systems smoke: direct actionable handoff move did not reach the normal immediate attack state: result=%s battle=%s." % [move_result, session.battle])
		get_tree().quit(1)
		return false

	var attack_result := BattleRules.perform_player_action(session, action_id)
	var selected_after_attack_id := String(BattleRules.get_selected_target(session.battle).get("battle_id", ""))
	var attack_context: Dictionary = attack_result.get("selected_target_continuity_context", {}) if attack_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var attack_closing: Dictionary = attack_result.get("selected_target_closing_context", {}) if attack_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var state_context: Dictionary = BattleRules.selected_target_continuity_context(session.battle)
	var state_closing: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	var attack_legality: Dictionary = BattleRules.selected_target_legality(session.battle)
	var attack_click_intent: Dictionary = BattleRules.selected_target_board_click_intent(session.battle)
	var attack_hex_summary: Dictionary = BattleRules.battle_hex_state_summary(session.battle)
	var attack_summary_legality: Dictionary = attack_hex_summary.get("selected_target_legality", {}) if attack_hex_summary.get("selected_target_legality", {}) is Dictionary else {}
	var attack_action_surface: Dictionary = BattleRules.get_action_surface(session)
	var handoff_action: Dictionary = attack_action_surface.get(String(attack_click_intent.get("action", "")), {}) if attack_action_surface.get(String(attack_click_intent.get("action", "")), {}) is Dictionary else {}
	var attack_target_context := BattleRules.describe_target_context(session).to_lower()
	var attack_action_guidance := BattleRules.describe_action_surface(session).to_lower()
	if (
		not bool(attack_result.get("ok", false))
		or String(attack_result.get("attack_action", "")) != action_id
		or String(attack_result.get("attack_target_battle_id", "")) != target_id
		or int(_battle_stack_by_id(session.battle, target_id).get("total_health", 0)) > 0
		or not bool(attack_result.get("attack_target_invalidated_after_attack", false))
		or bool(attack_result.get("attack_target_still_selected_after_attack", true))
		or bool(attack_result.get("attack_target_alive_after_attack", true))
		or selected_after_attack_id != handoff_target_id
		or String(attack_result.get("selected_target_after_attack_battle_id", "")) != handoff_target_id
		or not bool(attack_result.get("selected_target_valid_after_attack", false))
		or not bool(attack_result.get("selected_target_handoff_after_attack", false))
		or not bool(attack_result.get("selected_target_handoff_direct_actionable_after_attack", false))
		or bool(attack_result.get("selected_target_handoff_blocked_after_attack", false))
		or not bool(attack_result.get("selected_target_direct_actionable_after_attack", false))
		or not bool(attack_legality.get("attackable", false))
		or bool(attack_legality.get("blocked", false))
		or String(attack_click_intent.get("action", "")) not in ["strike", "shoot"]
		or handoff_action.is_empty()
		or bool(handoff_action.get("disabled", true))
		or bool(attack_result.get("selected_target_preserved_setup", false))
		or bool(attack_result.get("selected_target_closing_on_target", false))
		or not attack_context.is_empty()
		or not attack_closing.is_empty()
		or not state_context.is_empty()
		or not state_closing.is_empty()
		or session.battle.has(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
		or session.battle.has(BattleRules.SELECTED_TARGET_CLOSING_KEY)
		or attack_result.has("selected_target_actionable_after_move")
		or attack_result.has("selected_target_after_move_battle_id")
		or not bool(attack_hex_summary.get("selected_target_direct_actionable", false))
		or bool(attack_hex_summary.get("selected_target_preserved_setup", false))
		or bool(attack_hex_summary.get("selected_target_closing_on_target", false))
		or not bool(attack_summary_legality.get("attackable", false))
		or bool(attack_summary_legality.get("blocked", false))
		or "board click will" not in attack_target_context
		or "board click will" not in attack_action_guidance
		or "direct actionable after move" in attack_target_context
		or "direct actionable after move" in attack_action_guidance
		or "preserved setup target" in attack_target_context
		or "preserved setup target" in attack_action_guidance
		or "closing on target" in attack_target_context
		or "closing on target" in attack_action_guidance
	):
		push_error("Core systems smoke: invalidating immediate attack did not hand off to a normal directly attackable target: attack=%s legality=%s click=%s target=%s action=%s summary=%s battle=%s." % [attack_result, attack_legality, attack_click_intent, attack_target_context, attack_action_guidance, attack_hex_summary, session.battle])
		get_tree().quit(1)
		return false
	return true

func _run_battle_direct_actionable_after_move_prefers_attackable_handoff_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Core systems smoke: actionable-preferred handoff coverage could not find a battle encounter.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Core systems smoke: actionable-preferred handoff coverage could not create a battle payload.")
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(session)

	var player_melee := _first_stack_for_side(session.battle, "player", false)
	var selected_enemy := _first_stack_for_side(session.battle, "enemy", false)
	if player_melee.is_empty() or selected_enemy.is_empty():
		push_error("Core systems smoke: actionable-preferred handoff coverage could not find opposing melee stacks.")
		get_tree().quit(1)
		return false

	var player_id := String(player_melee.get("battle_id", ""))
	var target_id := String(selected_enemy.get("battle_id", ""))
	var blocked_handoff_id := "direct_actionable_after_move_blocked_handoff_candidate"
	var attackable_handoff_id := "direct_actionable_after_move_attackable_handoff_candidate"
	for enemy_id in _enemy_stack_ids_except_for_test(session.battle, target_id):
		_remove_battle_stack_for_test(session.battle, enemy_id)
	_ensure_enemy_stack_for_test(session.battle, selected_enemy, blocked_handoff_id)
	_ensure_enemy_stack_for_test(session.battle, selected_enemy, attackable_handoff_id)
	_set_stack_combat_profile_for_test(session.battle, player_id, 1, false, [])
	_set_stack_combat_profile_for_test(session.battle, target_id, 1, false, [])
	_set_stack_combat_profile_for_test(session.battle, blocked_handoff_id, 1, false, [])
	_set_stack_combat_profile_for_test(session.battle, attackable_handoff_id, 1, false, [])
	_set_stack_health_for_test(session.battle, player_id, 999)
	_set_stack_health_for_test(session.battle, target_id, 1)
	_set_stack_health_for_test(session.battle, blocked_handoff_id, 999)
	_set_stack_health_for_test(session.battle, attackable_handoff_id, 999)
	_set_stack_hex_for_test(session.battle, player_id, {"q": 0, "r": 3})
	_set_stack_hex_for_test(session.battle, target_id, {"q": 3, "r": 3})
	_set_stack_hex_for_test(session.battle, blocked_handoff_id, {"q": 5, "r": 3})
	_set_stack_hex_for_test(session.battle, attackable_handoff_id, {"q": 3, "r": 2})
	session.battle["distance"] = 0
	session.battle["turn_order"] = [player_id, player_id, player_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = player_id
	session.battle["selected_target_id"] = target_id
	session.battle.erase(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
	session.battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)

	var enemy_order := []
	for stack in session.battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("side", "")) == "enemy":
			enemy_order.append(String(stack.get("battle_id", "")))
	if enemy_order.find(blocked_handoff_id) < 0 or enemy_order.find(attackable_handoff_id) < 0 or enemy_order.find(blocked_handoff_id) > enemy_order.find(attackable_handoff_id):
		push_error("Core systems smoke: actionable-preferred handoff setup did not put the blocked candidate before the attackable candidate: order=%s." % [enemy_order])
		get_tree().quit(1)
		return false

	var first_result := BattleRules.move_active_stack_to_hex(session, 1, 3)
	var first_closing: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	if not bool(first_result.get("ok", false)) or first_closing.is_empty() or not bool(first_closing.get("ordinary_closing_target", false)):
		push_error("Core systems smoke: actionable-preferred handoff setup did not create the ordinary closing lead-in: result=%s context=%s battle=%s." % [first_result, first_closing, session.battle])
		get_tree().quit(1)
		return false

	var movement_intent := BattleRules.movement_intent_for_destination(session.battle, 2, 3)
	if (
		String(movement_intent.get("action", "")) != "move"
		or not bool(movement_intent.get("selected_target_closing_before_move", false))
		or not bool(movement_intent.get("sets_up_selected_target_attack", false))
		or not bool(movement_intent.get("selected_target_after_move_attackable", false))
	):
		push_error("Core systems smoke: actionable-preferred handoff setup did not preview the closing-to-actionable move: intent=%s battle=%s." % [movement_intent, session.battle])
		get_tree().quit(1)
		return false

	var move_result := BattleRules.move_active_stack_to_hex(session, 2, 3)
	var action_id := String(move_result.get("selected_target_after_move_board_click_action", ""))
	if (
		not bool(move_result.get("ok", false))
		or String(move_result.get("selected_target_after_move_battle_id", "")) != target_id
		or action_id not in ["strike", "shoot"]
		or not bool(move_result.get("selected_target_actionable_after_move", false))
		or bool(move_result.get("selected_target_preserved_setup", false))
		or bool(move_result.get("selected_target_closing_on_target", false))
	):
		push_error("Core systems smoke: actionable-preferred handoff move did not reach the normal immediate attack state: result=%s battle=%s." % [move_result, session.battle])
		get_tree().quit(1)
		return false

	var blocked_candidate_intent_before: Dictionary = BattleRules.board_click_attack_intent_for_target(session.battle, blocked_handoff_id)
	var attackable_candidate_intent_before: Dictionary = BattleRules.board_click_attack_intent_for_target(session.battle, attackable_handoff_id)
	if (
		not bool(blocked_candidate_intent_before.get("blocked", false))
		or bool(blocked_candidate_intent_before.get("attackable", false))
		or String(attackable_candidate_intent_before.get("action", "")) not in ["strike", "shoot"]
		or not bool(attackable_candidate_intent_before.get("attackable", false))
	):
		push_error("Core systems smoke: actionable-preferred handoff setup did not stage one blocked and one attackable survivor: blocked=%s attackable=%s battle=%s." % [blocked_candidate_intent_before, attackable_candidate_intent_before, session.battle])
		get_tree().quit(1)
		return false

	var attack_result := BattleRules.perform_player_action(session, action_id)
	var selected_after_attack_id := String(BattleRules.get_selected_target(session.battle).get("battle_id", ""))
	var attack_legality: Dictionary = BattleRules.selected_target_legality(session.battle)
	var attack_click_intent: Dictionary = BattleRules.selected_target_board_click_intent(session.battle)
	var blocked_candidate_intent_after: Dictionary = BattleRules.board_click_attack_intent_for_target(session.battle, blocked_handoff_id)
	var attack_hex_summary: Dictionary = BattleRules.battle_hex_state_summary(session.battle)
	var attack_summary_legality: Dictionary = attack_hex_summary.get("selected_target_legality", {}) if attack_hex_summary.get("selected_target_legality", {}) is Dictionary else {}
	var attack_context: Dictionary = attack_result.get("selected_target_continuity_context", {}) if attack_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var attack_closing: Dictionary = attack_result.get("selected_target_closing_context", {}) if attack_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var state_context: Dictionary = BattleRules.selected_target_continuity_context(session.battle)
	var state_closing: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	if (
		not bool(attack_result.get("ok", false))
		or String(attack_result.get("attack_action", "")) != action_id
		or String(attack_result.get("attack_target_battle_id", "")) != target_id
		or int(_battle_stack_by_id(session.battle, target_id).get("total_health", 0)) > 0
		or not bool(attack_result.get("attack_target_invalidated_after_attack", false))
		or bool(attack_result.get("attack_target_still_selected_after_attack", true))
		or bool(attack_result.get("attack_target_alive_after_attack", true))
		or selected_after_attack_id != attackable_handoff_id
		or String(attack_result.get("selected_target_after_attack_battle_id", "")) != attackable_handoff_id
		or not bool(attack_result.get("selected_target_valid_after_attack", false))
		or not bool(attack_result.get("selected_target_handoff_after_attack", false))
		or not bool(attack_result.get("selected_target_handoff_direct_actionable_after_attack", false))
		or bool(attack_result.get("selected_target_handoff_blocked_after_attack", false))
		or not bool(attack_result.get("selected_target_direct_actionable_after_attack", false))
		or not bool(attack_legality.get("attackable", false))
		or bool(attack_legality.get("blocked", false))
		or String(attack_click_intent.get("action", "")) not in ["strike", "shoot"]
		or not bool(blocked_candidate_intent_after.get("blocked", false))
		or bool(blocked_candidate_intent_after.get("attackable", false))
		or not bool(attack_hex_summary.get("selected_target_direct_actionable", false))
		or not bool(attack_summary_legality.get("attackable", false))
		or bool(attack_summary_legality.get("blocked", false))
		or bool(attack_result.get("selected_target_preserved_setup", false))
		or bool(attack_result.get("selected_target_closing_on_target", false))
		or not attack_context.is_empty()
		or not attack_closing.is_empty()
		or not state_context.is_empty()
		or not state_closing.is_empty()
		or session.battle.has(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
		or session.battle.has(BattleRules.SELECTED_TARGET_CLOSING_KEY)
		or attack_result.has("selected_target_actionable_after_move")
		or attack_result.has("selected_target_after_move_battle_id")
	):
		push_error("Core systems smoke: invalidating immediate attack did not prefer the attackable handoff target over the earlier blocked survivor: attack=%s legality=%s click=%s blocked=%s summary=%s battle=%s." % [attack_result, attack_legality, attack_click_intent, blocked_candidate_intent_after, attack_hex_summary, session.battle])
		get_tree().quit(1)
		return false
	return true

func _run_battle_direct_actionable_after_move_empty_handoff_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Core systems smoke: empty handoff coverage could not find a battle encounter.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Core systems smoke: empty handoff coverage could not create a battle payload.")
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(session)

	var player_melee := _first_stack_for_side(session.battle, "player", false)
	var selected_enemy := _first_stack_for_side(session.battle, "enemy", false)
	if player_melee.is_empty() or selected_enemy.is_empty():
		push_error("Core systems smoke: empty handoff coverage could not find opposing melee stacks.")
		get_tree().quit(1)
		return false

	var player_id := String(player_melee.get("battle_id", ""))
	var target_id := String(selected_enemy.get("battle_id", ""))
	for enemy_id in _enemy_stack_ids_except_for_test(session.battle, target_id):
		_remove_battle_stack_for_test(session.battle, enemy_id)
	_set_stack_combat_profile_for_test(session.battle, player_id, 1, false, [])
	_set_stack_combat_profile_for_test(session.battle, target_id, 1, false, [])
	_set_stack_health_for_test(session.battle, player_id, 999)
	_set_stack_health_for_test(session.battle, target_id, 1)
	_set_stack_hex_for_test(session.battle, player_id, {"q": 0, "r": 3})
	_set_stack_hex_for_test(session.battle, target_id, {"q": 3, "r": 3})
	session.battle["distance"] = 0
	session.battle["turn_order"] = [player_id, player_id, player_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = player_id
	session.battle["selected_target_id"] = target_id
	session.battle.erase(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
	session.battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)

	var first_result := BattleRules.move_active_stack_to_hex(session, 1, 3)
	var first_closing: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	if not bool(first_result.get("ok", false)) or first_closing.is_empty() or not bool(first_closing.get("ordinary_closing_target", false)):
		push_error("Core systems smoke: empty handoff setup did not create the ordinary closing lead-in: result=%s context=%s battle=%s." % [first_result, first_closing, session.battle])
		get_tree().quit(1)
		return false

	var movement_intent := BattleRules.movement_intent_for_destination(session.battle, 2, 3)
	if (
		String(movement_intent.get("action", "")) != "move"
		or not bool(movement_intent.get("selected_target_closing_before_move", false))
		or not bool(movement_intent.get("sets_up_selected_target_attack", false))
		or not bool(movement_intent.get("selected_target_after_move_attackable", false))
	):
		push_error("Core systems smoke: empty handoff setup did not preview the closing-to-actionable move: intent=%s battle=%s." % [movement_intent, session.battle])
		get_tree().quit(1)
		return false

	var move_result := BattleRules.move_active_stack_to_hex(session, 2, 3)
	var action_id := String(move_result.get("selected_target_after_move_board_click_action", ""))
	if (
		not bool(move_result.get("ok", false))
		or String(move_result.get("selected_target_after_move_battle_id", "")) != target_id
		or action_id not in ["strike", "shoot"]
		or not bool(move_result.get("selected_target_actionable_after_move", false))
		or bool(move_result.get("selected_target_preserved_setup", false))
		or bool(move_result.get("selected_target_closing_on_target", false))
	):
		push_error("Core systems smoke: empty handoff move did not reach the normal immediate attack state: result=%s battle=%s." % [move_result, session.battle])
		get_tree().quit(1)
		return false

	var attack_result := BattleRules.perform_player_action(session, action_id)
	var attack_context: Dictionary = attack_result.get("selected_target_continuity_context", {}) if attack_result.get("selected_target_continuity_context", {}) is Dictionary else {}
	var attack_closing: Dictionary = attack_result.get("selected_target_closing_context", {}) if attack_result.get("selected_target_closing_context", {}) is Dictionary else {}
	var attack_legality: Dictionary = attack_result.get("selected_target_after_attack_legality", {}) if attack_result.get("selected_target_after_attack_legality", {}) is Dictionary else {}
	var attack_click_intent: Dictionary = attack_result.get("selected_target_after_attack_board_click_intent", {}) if attack_result.get("selected_target_after_attack_board_click_intent", {}) is Dictionary else {}
	var attack_message := String(attack_result.get("message", "")).to_lower()
	if (
		not bool(attack_result.get("ok", false))
		or String(attack_result.get("state", "")) != "victory"
		or not session.battle.is_empty()
		or String(attack_result.get("attack_action", "")) != action_id
		or String(attack_result.get("attack_target_battle_id", "")) != target_id
		or not bool(attack_result.get("attack_target_invalidated_after_attack", false))
		or bool(attack_result.get("attack_target_still_selected_after_attack", true))
		or bool(attack_result.get("attack_target_alive_after_attack", true))
		or String(attack_result.get("active_stack_after_attack_battle_id", "")) != ""
		or String(attack_result.get("selected_target_after_attack_battle_id", "")) != ""
		or bool(attack_result.get("selected_target_valid_after_attack", true))
		or bool(attack_result.get("selected_target_handoff_after_attack", true))
		or bool(attack_result.get("selected_target_handoff_direct_actionable_after_attack", true))
		or bool(attack_result.get("selected_target_handoff_blocked_after_attack", true))
		or bool(attack_result.get("selected_target_direct_actionable_after_attack", true))
		or bool(attack_result.get("selected_target_preserved_setup", true))
		or bool(attack_result.get("selected_target_closing_on_target", true))
		or not attack_context.is_empty()
		or not attack_closing.is_empty()
		or bool(attack_legality.get("attackable", false))
		or bool(attack_legality.get("blocked", false))
		or String(attack_click_intent.get("action", "")) != ""
		or attack_result.has("selected_target_actionable_after_move")
		or attack_result.has("selected_target_after_move_battle_id")
		or attack_result.has("post_move_target_guidance")
		or "direct actionable after move" in attack_message
		or "preserved setup target" in attack_message
		or "closing on target" in attack_message
	):
		push_error("Core systems smoke: invalidating immediate attack with no handoff did not settle onto an empty normal post-attack state: attack=%s legality=%s click=%s." % [attack_result, attack_legality, attack_click_intent])
		get_tree().quit(1)
		return false
	return true

func _run_battle_setup_move_target_blocked_surface_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Core systems smoke: blocked setup-target surface coverage could not find a battle encounter.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Core systems smoke: blocked setup-target surface coverage could not create a battle payload.")
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(session)

	var player_melee := _first_stack_for_side(session.battle, "player", false)
	var source_enemy := _first_stack_for_side(session.battle, "enemy", false)
	if player_melee.is_empty() or source_enemy.is_empty():
		push_error("Core systems smoke: blocked setup-target surface coverage could not find source stacks.")
		get_tree().quit(1)
		return false

	var player_id := String(player_melee.get("battle_id", ""))
	var source_enemy_id := String(source_enemy.get("battle_id", ""))
	var followup_player_id := "setup_move_followup_player"
	var continuity_target_id := "setup_move_blocked_surface_target"
	_ensure_player_stack_for_test(session.battle, player_melee, followup_player_id)
	_ensure_enemy_stack_for_test(session.battle, source_enemy, continuity_target_id)
	_remove_battle_stack_for_test(session.battle, source_enemy_id)
	_set_stack_hex_for_test(session.battle, player_id, {"q": 4, "r": 3})
	_set_stack_hex_for_test(session.battle, followup_player_id, {"q": 0, "r": 0})
	_set_stack_health_for_test(session.battle, player_id, 999)
	_set_stack_health_for_test(session.battle, followup_player_id, 999)
	session.battle["distance"] = 0
	session.battle["turn_order"] = [player_id, followup_player_id, continuity_target_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = player_id
	session.battle["selected_target_id"] = continuity_target_id

	var setup_case := _stage_later_attack_destination_for_test(session.battle, player_id, continuity_target_id)
	if setup_case.is_empty():
		push_error("Core systems smoke: blocked setup-target surface coverage could not stage a setup move.")
		get_tree().quit(1)
		return false
	var destination: Dictionary = setup_case.get("destination", {})
	var target_hex: Dictionary = setup_case.get("target_hex", {})
	var followup_hex := _far_open_hex_for_test(session.battle, target_hex, 3)
	if followup_hex.is_empty():
		push_error("Core systems smoke: blocked setup-target surface coverage could not place the follow-up stack away from the target.")
		get_tree().quit(1)
		return false
	_set_stack_hex_for_test(session.battle, followup_player_id, followup_hex)
	session.battle["selected_target_id"] = continuity_target_id
	var movement_intent := BattleRules.movement_intent_for_destination(
		session.battle,
		int(destination.get("q", -1)),
		int(destination.get("r", -1))
	)
	if not bool(movement_intent.get("sets_up_selected_target_attack", false)):
		push_error("Core systems smoke: blocked setup-target surface lost the setup-move preview before execution: %s." % movement_intent)
		get_tree().quit(1)
		return false

	var move_result := BattleRules.move_active_stack_to_hex(
		session,
		int(destination.get("q", -1)),
		int(destination.get("r", -1))
	)
	if not bool(move_result.get("ok", false)) or not bool(move_result.get("selected_target_continuity_preserved", false)):
		push_error("Core systems smoke: blocked setup-target surface move did not preserve target continuity: %s." % move_result)
		get_tree().quit(1)
		return false
	if String(BattleRules.get_active_stack(session.battle).get("battle_id", "")) != followup_player_id:
		push_error("Core systems smoke: blocked setup-target surface did not stop on the follow-up player stack: %s." % move_result)
		get_tree().quit(1)
		return false
	if String(BattleRules.get_selected_target(session.battle).get("battle_id", "")) != continuity_target_id:
		push_error("Core systems smoke: blocked setup-target surface did not keep the preserved target selected: %s." % move_result)
		get_tree().quit(1)
		return false

	var post_legality: Dictionary = BattleRules.selected_target_legality(session.battle)
	var post_click_intent: Dictionary = BattleRules.selected_target_board_click_intent(session.battle)
	var continuity_context: Dictionary = BattleRules.selected_target_continuity_context(session.battle)
	var post_target_guidance := BattleRules.describe_target_context(session).to_lower()
	var post_action_guidance := BattleRules.describe_action_surface(session).to_lower()
	if (
		not bool(post_legality.get("blocked", false))
		or not bool(post_click_intent.get("blocked", false))
		or continuity_context.is_empty()
		or not bool(continuity_context.get("blocked", false))
		or "still blocked" not in String(continuity_context.get("message", "")).to_lower()
		or "still blocked" not in post_target_guidance
		or "still blocked" not in post_action_guidance
	):
		push_error("Core systems smoke: preserved setup target did not surface the still-blocked post-move state clearly: legality=%s intent=%s context=%s target=%s action=%s." % [post_legality, post_click_intent, continuity_context, post_target_guidance, post_action_guidance])
		get_tree().quit(1)
		return false
	return true

func _run_battle_commander_spell_cadence_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _encounter_by_id(session, "encounter_hollow_mire")
	if encounter.is_empty():
		push_error("Core systems smoke: commander spell cadence coverage could not find Hollow Mire.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Core systems smoke: commander spell cadence coverage could not create a battle payload.")
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(session)

	var first_result := BattleRules.perform_player_action(session, "defend")
	if not bool(first_result.get("ok", false)):
		push_error("Core systems smoke: commander cadence setup first defend failed: %s." % first_result)
		get_tree().quit(1)
		return false
	var second_result := BattleRules.perform_player_action(session, "defend")
	if not bool(second_result.get("ok", false)):
		push_error("Core systems smoke: commander cadence setup second defend failed: %s." % second_result)
		get_tree().quit(1)
		return false
	var enemy_phase_message := String(second_result.get("message", ""))
	var cast_count := _substring_count(enemy_phase_message, " casts ")
	if cast_count != 1:
		push_error("Core systems smoke: enemy commander should cast once per round, got %d casts in: %s." % [cast_count, enemy_phase_message])
		get_tree().quit(1)
		return false
	var cast_rounds = session.battle.get(BattleRules.COMMANDER_SPELL_CAST_ROUNDS_KEY, {})
	var enemy_cast_round := int(cast_rounds.get("enemy", 0)) if cast_rounds is Dictionary else 0
	if enemy_cast_round <= 0 or enemy_cast_round > int(session.battle.get("round", 1)):
		push_error("Core systems smoke: enemy commander spell cast round was not saved on battle state.")
		get_tree().quit(1)
		return false
	var restored = _clone_session(session)
	var restored_cast_rounds = restored.battle.get(BattleRules.COMMANDER_SPELL_CAST_ROUNDS_KEY, {})
	if not (restored_cast_rounds is Dictionary) or int(restored_cast_rounds.get("enemy", 0)) != enemy_cast_round:
		push_error("Core systems smoke: commander spell cadence state did not survive restore normalization.")
		get_tree().quit(1)
		return false

	var player_session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var player_encounter := _encounter_by_id(player_session, "encounter_hollow_mire")
	if player_encounter.is_empty():
		push_error("Core systems smoke: player commander spell cadence coverage could not find Hollow Mire.")
		get_tree().quit(1)
		return false
	player_session.battle = BattleRules.create_battle_payload(player_session, player_encounter)
	if player_session.battle.is_empty():
		push_error("Core systems smoke: player commander spell cadence coverage could not create a battle payload.")
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(player_session)

	var caster_stack := _first_stack_for_side(player_session.battle, "player", false)
	if caster_stack.is_empty():
		caster_stack = _first_stack_for_side(player_session.battle, "player", true)
	var target_stack := _first_stack_for_side(player_session.battle, "enemy", false)
	if target_stack.is_empty():
		target_stack = _first_stack_for_side(player_session.battle, "enemy", true)
	if caster_stack.is_empty() or target_stack.is_empty():
		push_error("Core systems smoke: player commander spell cadence coverage could not find caster and target stacks.")
		get_tree().quit(1)
		return false
	var caster_id := String(caster_stack.get("battle_id", ""))
	var target_id := String(target_stack.get("battle_id", ""))
	var followup_stack := {}
	for stack in player_session.battle.get("stacks", []):
		if (
			stack is Dictionary
			and String(stack.get("side", "")) == "player"
			and String(stack.get("battle_id", "")) != caster_id
			and int(stack.get("total_health", 0)) > 0
		):
			followup_stack = stack
			break
	if followup_stack.is_empty():
		followup_stack = _ensure_player_stack_for_test(
			player_session.battle,
			caster_stack,
			"test_player_spell_followup_stack"
		)
	var followup_id := String(followup_stack.get("battle_id", ""))
	_set_stack_health_for_test(player_session.battle, target_id, 999)
	player_session.battle["turn_order"] = [caster_id, followup_id]
	player_session.battle["turn_index"] = 0
	player_session.battle["active_stack_id"] = caster_id
	player_session.battle["selected_target_id"] = target_id
	player_session.battle.erase(BattleRules.COMMANDER_SPELL_CAST_ROUNDS_KEY)

	var player_spell_result := BattleRules.cast_player_spell(player_session, "spell_cinder_burst")
	if not bool(player_spell_result.get("ok", false)):
		push_error("Core systems smoke: player commander spell cadence setup cast failed: %s." % player_spell_result)
		get_tree().quit(1)
		return false
	if String(BattleRules.get_active_stack(player_session.battle).get("battle_id", "")) != followup_id:
		push_error("Core systems smoke: player commander spell cadence did not stop on a follow-up player stack: %s." % player_spell_result)
		get_tree().quit(1)
		return false
	var repeat_spell_result := BattleRules.cast_player_spell(player_session, "spell_cinder_burst")
	var spell_actions := BattleRules.get_spell_actions(player_session)
	var spell_timing := BattleRules.describe_spell_timing_board(player_session).to_lower()
	var consequence_board := BattleRules.describe_order_consequence_board(player_session).to_lower()
	var spellbook_summary := BattleRules.describe_spellbook(player_session).to_lower()
	if (
		not spell_actions.is_empty()
		or bool(repeat_spell_result.get("ok", false))
		or "already cast" not in String(repeat_spell_result.get("message", "")).to_lower()
		or "already cast this round" not in spell_timing
		or "already cast this round" not in consequence_board
		or "already cast this round" not in spellbook_summary
	):
		push_error("Core systems smoke: player commander spell cadence was not surfaced truthfully after a same-round cast: repeat=%s actions=%s timing=%s consequence=%s spellbook=%s." % [repeat_spell_result, spell_actions, spell_timing, consequence_board, spellbook_summary])
		get_tree().quit(1)
		return false
	return true

func _run_battle_spell_clears_closing_context_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		push_error("Core systems smoke: spell closing-clear coverage could not find a battle encounter.")
		get_tree().quit(1)
		return false
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		push_error("Core systems smoke: spell closing-clear coverage could not create a battle payload.")
		get_tree().quit(1)
		return false
	BattleRules.normalize_battle_state(session)

	var player_melee := _first_stack_for_side(session.battle, "player", false)
	var selected_enemy := _first_stack_for_side(session.battle, "enemy", false)
	if player_melee.is_empty() or selected_enemy.is_empty():
		push_error("Core systems smoke: spell closing-clear coverage could not find opposing melee stacks.")
		get_tree().quit(1)
		return false

	var player_id := String(player_melee.get("battle_id", ""))
	var target_id := String(selected_enemy.get("battle_id", ""))
	for enemy_id in _enemy_stack_ids_except_for_test(session.battle, target_id):
		_remove_battle_stack_for_test(session.battle, enemy_id)
	_set_stack_combat_profile_for_test(session.battle, player_id, 1, false, [])
	_set_stack_health_for_test(session.battle, player_id, 999)
	_set_stack_health_for_test(session.battle, target_id, 999)
	_set_stack_hex_for_test(session.battle, player_id, {"q": 0, "r": 3})
	_set_stack_hex_for_test(session.battle, target_id, {"q": 4, "r": 3})
	session.battle["distance"] = 0
	session.battle["turn_order"] = [player_id, player_id]
	session.battle["turn_index"] = 0
	session.battle["active_stack_id"] = player_id
	session.battle["selected_target_id"] = target_id
	session.battle.erase(BattleRules.SELECTED_TARGET_CONTINUITY_KEY)
	session.battle.erase(BattleRules.SELECTED_TARGET_CLOSING_KEY)

	var close_intent := BattleRules.movement_intent_for_destination(session.battle, 1, 3)
	if (
		String(close_intent.get("action", "")) != "move"
		or not bool(close_intent.get("closes_on_selected_target", false))
		or bool(close_intent.get("sets_up_selected_target_attack", false))
	):
		push_error("Core systems smoke: spell closing-clear setup did not stage an ordinary closing move: intent=%s battle=%s." % [close_intent, session.battle])
		get_tree().quit(1)
		return false

	var close_result := BattleRules.move_active_stack_to_hex(session, 1, 3)
	var closing_before_spell: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	if (
		not bool(close_result.get("ok", false))
		or closing_before_spell.is_empty()
		or not bool(closing_before_spell.get("ordinary_closing_target", false))
	):
		push_error("Core systems smoke: spell closing-clear setup did not create ordinary closing context: result=%s context=%s battle=%s." % [close_result, closing_before_spell, session.battle])
		get_tree().quit(1)
		return false

	var cast_rounds_value = session.battle.get(BattleRules.COMMANDER_SPELL_CAST_ROUNDS_KEY, {})
	var cast_rounds: Dictionary = cast_rounds_value.duplicate(true) if cast_rounds_value is Dictionary else {}
	cast_rounds["player"] = int(session.battle.get("round", 1))
	session.battle[BattleRules.COMMANDER_SPELL_CAST_ROUNDS_KEY] = cast_rounds
	var blocked_spell_result := BattleRules.cast_player_spell(session, "spell_cinder_burst")
	var closing_after_blocked_spell: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	var blocked_action_guidance := BattleRules.describe_action_surface(session).to_lower()
	var blocked_target_guidance := BattleRules.describe_target_context(session).to_lower()
	if (
		bool(blocked_spell_result.get("ok", false))
		or String(blocked_spell_result.get("state", "")) != "invalid"
		or not session.battle.has(BattleRules.SELECTED_TARGET_CLOSING_KEY)
		or closing_after_blocked_spell.is_empty()
		or not bool(closing_after_blocked_spell.get("ordinary_closing_target", false))
		or "closing on target" not in blocked_action_guidance
		or "closing on target" not in blocked_target_guidance
	):
		push_error("Core systems smoke: invalid commander spell attempt mutated ordinary closing context: spell=%s closing=%s action=%s target=%s battle=%s." % [blocked_spell_result, closing_after_blocked_spell, blocked_action_guidance, blocked_target_guidance, session.battle])
		get_tree().quit(1)
		return false

	var blocked_order_result := BattleRules.perform_player_action(session, "shoot")
	var closing_after_blocked_order: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	var blocked_order_action_guidance := BattleRules.describe_action_surface(session).to_lower()
	var blocked_order_target_guidance := BattleRules.describe_target_context(session).to_lower()
	if (
		bool(blocked_order_result.get("ok", false))
		or String(blocked_order_result.get("state", "")) != "invalid"
		or not session.battle.has(BattleRules.SELECTED_TARGET_CLOSING_KEY)
		or closing_after_blocked_order.is_empty()
		or not bool(closing_after_blocked_order.get("ordinary_closing_target", false))
		or "closing on target" not in blocked_order_action_guidance
		or "closing on target" not in blocked_order_target_guidance
	):
		push_error("Core systems smoke: invalid ordinary battle order mutated ordinary closing context: order=%s closing=%s action=%s target=%s battle=%s." % [blocked_order_result, closing_after_blocked_order, blocked_order_action_guidance, blocked_order_target_guidance, session.battle])
		get_tree().quit(1)
		return false
	cast_rounds.erase("player")
	session.battle[BattleRules.COMMANDER_SPELL_CAST_ROUNDS_KEY] = cast_rounds

	var spell_result := BattleRules.cast_player_spell(session, "spell_cinder_burst")
	var closing_after_spell: Dictionary = BattleRules.selected_target_closing_context(session.battle)
	var action_guidance := BattleRules.describe_action_surface(session).to_lower()
	var target_guidance := BattleRules.describe_target_context(session).to_lower()
	var hex_summary: Dictionary = BattleRules.battle_hex_state_summary(session.battle)
	var summary_closing: Dictionary = hex_summary.get("selected_target_closing_context", {}) if hex_summary.get("selected_target_closing_context", {}) is Dictionary else {}
	if (
		not bool(spell_result.get("ok", false))
		or session.battle.has(BattleRules.SELECTED_TARGET_CLOSING_KEY)
		or not closing_after_spell.is_empty()
		or not summary_closing.is_empty()
		or bool(hex_summary.get("selected_target_closing_on_target", false))
		or "closing on target" in action_guidance
		or "closing on target" in target_guidance
	):
		push_error("Core systems smoke: commander spell action left stale ordinary closing context: spell=%s closing=%s action=%s target=%s summary=%s battle=%s." % [spell_result, closing_after_spell, action_guidance, target_guidance, hex_summary, session.battle])
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

func _run_extended_strategic_soak_regression() -> bool:
	if not _run_followup_convoy_reopen_soak_regression():
		return false
	if not _run_enemy_weekly_economy_soak_regression():
		return false
	return true

func _run_followup_convoy_reopen_soak_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	if not _capture_duskfen_for_long_horizon(session):
		return false
	_boost_active_hero_route_security(session)

	var source_town_id := "riverwatch_hold"
	var route_node_id := "river_free_company"
	_set_resource_node_controller(session, route_node_id, "player")
	_set_town_available_recruits(
		session,
		source_town_id,
		{
			"unit_river_guard": 12,
			"unit_ember_archer": 8,
		}
	)
	_set_active_hero_position(session, Vector2i(0, 4))
	_set_active_hero_movement(session, int(session.overworld.get("movement", {}).get("max", 0)))
	var response_result := OverworldRules.perform_context_action(session, "site_response")
	if not bool(response_result.get("ok", false)):
		push_error("Core systems smoke: extended soak could not issue the route response order.")
		get_tree().quit(1)
		return false

	var route_node := _resource_node_by_placement(session, route_node_id)
	var delivery_state: Dictionary = OverworldRules._resource_site_delivery_state(session, route_node)
	if not bool(delivery_state.get("active", false)):
		push_error("Core systems smoke: extended soak response did not load the first convoy.")
		get_tree().quit(1)
		return false
	if int(delivery_state.get("arrival_day", 0)) > int(route_node.get("response_until_day", 0)):
		push_error("Core systems smoke: extended soak setup failed to keep the first convoy inside the escort window.")
		get_tree().quit(1)
		return false
	var target_garrison_before := _army_stack_headcount(_town_by_placement(session, "duskfen_bastion").get("garrison", []))
	var first_arrival_day := int(delivery_state.get("arrival_day", 0))
	while int(session.day) < first_arrival_day:
		var turn_result := OverworldRules.end_turn(session)
		if not bool(turn_result.get("ok", false)):
			push_error("Core systems smoke: extended soak day advance failed before first convoy arrival.")
			get_tree().quit(1)
			return false
		if not session.battle.is_empty() and not _force_player_victory_if_battle_started(session, "extended convoy reopen"):
			return false

	var target_garrison_after := _army_stack_headcount(_town_by_placement(session, "duskfen_bastion").get("garrison", []))
	if target_garrison_after <= target_garrison_before:
		push_error("Core systems smoke: first extended-soak convoy did not reinforce the occupied town.")
		get_tree().quit(1)
		return false
	var followup_node := _resource_node_by_placement(session, route_node_id)
	var followup_delivery: Dictionary = OverworldRules._resource_site_delivery_state(session, followup_node)
	if not bool(followup_delivery.get("active", false)):
		push_error("Core systems smoke: active route response did not reopen a follow-up convoy after delivery.")
		get_tree().quit(1)
		return false
	if String(followup_delivery.get("target_id", "")) != "duskfen_bastion" or _recruit_payload_total(followup_delivery.get("manifest", {})) <= 0:
		push_error("Core systems smoke: follow-up convoy lost its occupied-town target or manifest.")
		get_tree().quit(1)
		return false

	session.game_state = "overworld"
	var save_path := SaveService.save_manual_session(session.to_dict(), 1)
	if save_path == "":
		push_error("Core systems smoke: extended-soak follow-up convoy could not be saved.")
		get_tree().quit(1)
		return false
	var summary := SaveService.inspect_manual_slot(1)
	if not SaveService.can_load_summary(summary):
		push_error("Core systems smoke: extended-soak follow-up convoy save was not loadable.")
		get_tree().quit(1)
		return false
	var restored = SaveService.restore_session_from_summary(summary)
	if restored == null:
		push_error("Core systems smoke: extended-soak follow-up convoy did not restore through SaveService.")
		get_tree().quit(1)
		return false
	var restored_delivery: Dictionary = OverworldRules._resource_site_delivery_state(restored, _resource_node_by_placement(restored, route_node_id))
	if String(restored_delivery.get("target_id", "")) != "duskfen_bastion" or _recruit_payload_total(restored_delivery.get("manifest", {})) <= 0:
		push_error("Core systems smoke: restored extended-soak follow-up convoy lost target or manifest.")
		get_tree().quit(1)
		return false

	session = restored
	_append_route_disruption_raid(session, route_node_id)
	var blocked_garrison_before := _army_stack_headcount(_town_by_placement(session, "duskfen_bastion").get("garrison", []))
	var hostile_pressure_before := int(_enemy_state_by_faction(session, "faction_mireclaw").get("pressure", 0))
	var disruption_result := OverworldRules.end_turn(session)
	if not bool(disruption_result.get("ok", false)):
		push_error("Core systems smoke: extended-soak disruption day advance failed.")
		get_tree().quit(1)
		return false
	if String(_resource_node_by_placement(session, route_node_id).get("delivery_controller_id", "")) != "":
		push_error("Core systems smoke: disrupted follow-up convoy stayed live after the route was seized.")
		get_tree().quit(1)
		return false
	if String(_resource_node_by_placement(session, route_node_id).get("collected_by_faction_id", "")) != "faction_mireclaw":
		push_error("Core systems smoke: disrupted follow-up convoy did not leave the route in hostile hands.")
		get_tree().quit(1)
		return false
	if _army_stack_headcount(_town_by_placement(session, "duskfen_bastion").get("garrison", [])) != blocked_garrison_before:
		push_error("Core systems smoke: blocked follow-up convoy still reached the occupied town.")
		get_tree().quit(1)
		return false
	if int(_enemy_state_by_faction(session, "faction_mireclaw").get("pressure", 0)) <= hostile_pressure_before:
		push_error("Core systems smoke: disrupted follow-up convoy did not raise hostile pressure.")
		get_tree().quit(1)
		return false
	var disrupted_restore = _clone_session(session)
	if String(_resource_node_by_placement(disrupted_restore, route_node_id).get("delivery_controller_id", "")) != "":
		push_error("Core systems smoke: restored extended-soak disruption resurrected the cleared convoy.")
		get_tree().quit(1)
		return false
	return true

func _run_enemy_weekly_economy_soak_regression() -> bool:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"story",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	EnemyTurnRules.normalize_enemy_states(session)
	_set_enemy_treasury(session, "faction_mireclaw", {"gold": 12000, "wood": 90, "ore": 90})
	_set_enemy_pressure(session, "faction_mireclaw", 0)
	_set_town_garrison(session, "duskfen_bastion", [])
	_set_town_available_recruits(
		session,
		"duskfen_bastion",
		{
			"unit_mire_slinger": 5,
			"unit_blackbranch_cutthroat": 4,
		}
	)
	var built_before := _normalized_array_size(_town_by_placement(session, "duskfen_bastion").get("built_buildings", []))
	var garrison_before := _army_stack_headcount(_town_by_placement(session, "duskfen_bastion").get("garrison", []))
	var treasury_before := int(_enemy_state_by_faction(session, "faction_mireclaw").get("treasury", {}).get("gold", 0))
	var weekly_muster_seen := false
	var raid_seen := false
	for _day_index in range(7):
		session.day += 1
		var turn_result := EnemyTurnRules.run_enemy_turn(session)
		var turn_message := String(turn_result.get("message", ""))
		if "musters fresh levies" in turn_message:
			weekly_muster_seen = true
		if EnemyTurnRules.active_raid_count(session, "faction_mireclaw") > 0:
			raid_seen = true
		if not session.battle.is_empty() and not _force_player_victory_if_battle_started(session, "extended enemy economy soak"):
			return false

	var enemy_town := _town_by_placement(session, "duskfen_bastion")
	var built_after := _normalized_array_size(enemy_town.get("built_buildings", []))
	var garrison_after := _army_stack_headcount(enemy_town.get("garrison", []))
	var treasury_after := int(_enemy_state_by_faction(session, "faction_mireclaw").get("treasury", {}).get("gold", 0))
	if built_after <= built_before:
		push_error("Core systems smoke: extended enemy economy soak did not build in the enemy town over repeated days.")
		get_tree().quit(1)
		return false
	if garrison_after <= garrison_before:
		push_error("Core systems smoke: extended enemy economy soak did not spend recruits on town garrison stability.")
		get_tree().quit(1)
		return false
	if treasury_after >= treasury_before:
		push_error("Core systems smoke: extended enemy economy soak did not spend down hostile treasury.")
		get_tree().quit(1)
		return false
	if not weekly_muster_seen:
		push_error("Core systems smoke: extended enemy economy soak did not cross a weekly muster tick.")
		get_tree().quit(1)
		return false
	if not raid_seen:
		push_error("Core systems smoke: extended enemy economy soak never launched or maintained a raid host.")
		get_tree().quit(1)
		return false
	var restored = _clone_session(session)
	if int(restored.day) != int(session.day):
		push_error("Core systems smoke: restored extended enemy economy soak changed the campaign day.")
		get_tree().quit(1)
		return false
	if _normalized_array_size(_town_by_placement(restored, "duskfen_bastion").get("built_buildings", [])) != built_after:
		push_error("Core systems smoke: restored extended enemy economy soak lost enemy build continuity.")
		get_tree().quit(1)
		return false
	if _army_stack_headcount(_town_by_placement(restored, "duskfen_bastion").get("garrison", [])) != garrison_after:
		push_error("Core systems smoke: restored extended enemy economy soak lost enemy garrison continuity.")
		get_tree().quit(1)
		return false
	if int(_enemy_state_by_faction(restored, "faction_mireclaw").get("treasury", {}).get("gold", 0)) != treasury_after:
		push_error("Core systems smoke: restored extended enemy economy soak changed hostile treasury.")
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

	var stale_session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	var stale_town := _town_by_placement(stale_session, "duskfen_bastion")
	if stale_town.is_empty():
		push_error("Core systems smoke: sample scenario is missing the stale hostile town restore target.")
		get_tree().quit(1)
		return false
	_set_active_hero_position(stale_session, Vector2i(int(stale_town.get("x", 0)), int(stale_town.get("y", 0))))
	var stale_result := OverworldRules.capture_active_town(stale_session)
	if String(stale_result.get("route", "")) != "battle" or stale_session.battle.is_empty():
		push_error("Core systems smoke: stale town-assault setup did not create a live assault battle.")
		get_tree().quit(1)
		return false
	var stale_battle: Dictionary = stale_session.battle.duplicate(true)
	stale_battle.erase("context")
	stale_battle.erase("stacks")
	stale_session.battle = stale_battle
	_set_town_owner(stale_session, "duskfen_bastion", "player")
	stale_session.game_state = "overworld"

	var stale_path := SaveService.save_manual_session(stale_session.to_dict(), 1)
	if stale_path == "":
		push_error("Core systems smoke: stale town-assault save/restore setup could not write the manual slot.")
		get_tree().quit(1)
		return false
	var stale_summary := SaveService.inspect_manual_slot(1)
	if not SaveService.can_load_summary(stale_summary):
		push_error("Core systems smoke: stale town-assault save should remain loadable as an overworld snapshot.")
		get_tree().quit(1)
		return false
	if String(stale_summary.get("resume_target", "")) == "battle":
		push_error("Core systems smoke: stale post-capture town-assault save must not advertise battle resume.")
		get_tree().quit(1)
		return false
	var stale_restored = SaveService.restore_session_from_summary(stale_summary)
	if stale_restored == null:
		push_error("Core systems smoke: stale town-assault save could not be restored through the public save service.")
		get_tree().quit(1)
		return false
	if not stale_restored.battle.is_empty():
		push_error("Core systems smoke: stale post-capture battle payload was not discarded on restore.")
		get_tree().quit(1)
		return false
	if String(_town_by_placement(stale_restored, "duskfen_bastion").get("owner", "")) != "player":
		push_error("Core systems smoke: stale post-capture restore rewound captured town ownership.")
		get_tree().quit(1)
		return false
	if String(stale_restored.game_state) != "overworld" or SaveService.resume_target_for_session(stale_restored) != "overworld":
		push_error("Core systems smoke: stale post-capture restore did not normalize to overworld resume.")
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

func _boost_active_hero_route_security(session) -> void:
	var command := {"attack": 5, "defense": 5, "power": 5, "knowledge": 5}
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["level"] = max(4, int(hero.get("level", 1)))
		hero["command"] = command.duplicate(true)
		session.overworld["hero"] = hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var roster_hero = heroes[index]
		if not (roster_hero is Dictionary):
			continue
		if String(roster_hero.get("id", "")) != String(session.overworld.get("active_hero_id", "")):
			continue
		roster_hero["level"] = max(4, int(roster_hero.get("level", 1)))
		roster_hero["command"] = command.duplicate(true)
		heroes[index] = roster_hero
		break
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

func _recruit_unit_count(value: Variant, unit_id: String) -> int:
	if not (value is Dictionary):
		return 0
	return max(0, int(value.get(unit_id, 0)))

func _army_unit_count(army: Variant, unit_id: String) -> int:
	if not (army is Dictionary):
		return 0
	var total := 0
	var stacks = army.get("stacks", [])
	if not (stacks is Array):
		return total
	for stack in stacks:
		if not (stack is Dictionary) or String(stack.get("unit_id", "")) != unit_id:
			continue
		total += max(0, int(stack.get("count", stack.get("base_count", 0))))
	return total

func _normalized_array_size(value: Variant) -> int:
	return value.size() if value is Array else 0

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

func _force_player_victory_if_battle_started(session, label: String) -> bool:
	if session == null or session.battle.is_empty():
		return true
	var stacks = session.battle.get("stacks", [])
	var has_player_stack := false
	var has_player_survivor := false
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary):
			continue
		match String(stack.get("side", "")):
			"enemy":
				stack["total_health"] = 0
			"player":
				has_player_stack = true
				if int(stack.get("total_health", 0)) > 0:
					has_player_survivor = true
				elif not has_player_survivor:
					stack["total_health"] = max(1, int(stack.get("unit_hp", 1)))
					has_player_survivor = true
		stacks[index] = stack
	if not has_player_stack:
		stacks.append(BattleRules._build_battle_stack("unit_river_guard", 1, "player", 0, {"source_type": "test_forced_resolution"}))
		has_player_survivor = true
	session.battle["stacks"] = stacks
	var outcome := BattleRules.resolve_if_battle_ready(session)
	if String(outcome.get("state", "")) != "victory":
		push_error("Core systems smoke: %s could not deterministically resolve the battle interruption." % label)
		get_tree().quit(1)
		return false
	return true

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

func _living_battle_stack_count(battle: Dictionary) -> int:
	var total := 0
	for stack in battle.get("stacks", []):
		if stack is Dictionary and int(stack.get("total_health", 0)) > 0:
			total += 1
	return total

func _battle_stack_by_id(battle: Dictionary, battle_id: String) -> Dictionary:
	for stack in battle.get("stacks", []):
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			return stack
	return {}

func _ensure_enemy_stack_for_test(battle: Dictionary, source_stack: Dictionary, battle_id: String) -> Dictionary:
	var existing := _battle_stack_by_id(battle, battle_id)
	if not existing.is_empty():
		return existing
	var clone := source_stack.duplicate(true)
	clone["battle_id"] = battle_id
	clone["side"] = "enemy"
	clone["name"] = "%s Test Target" % String(source_stack.get("name", "Enemy"))
	clone["total_health"] = max(1, int(clone.get("total_health", clone.get("unit_hp", clone.get("hp", 1)))))
	var stacks: Array = battle.get("stacks", [])
	stacks.append(clone)
	battle["stacks"] = stacks
	return clone

func _ensure_player_stack_for_test(battle: Dictionary, source_stack: Dictionary, battle_id: String) -> Dictionary:
	var existing := _battle_stack_by_id(battle, battle_id)
	if not existing.is_empty():
		return existing
	var clone := source_stack.duplicate(true)
	clone["battle_id"] = battle_id
	clone["side"] = "player"
	clone["name"] = "%s Follow-up Test Stack" % String(source_stack.get("name", "Player"))
	clone["ranged"] = false
	clone["total_health"] = max(1, int(clone.get("total_health", clone.get("unit_hp", clone.get("hp", 1)))))
	var stacks: Array = battle.get("stacks", [])
	stacks.append(clone)
	battle["stacks"] = stacks
	return clone

func _remove_battle_stack_for_test(battle: Dictionary, battle_id: String) -> void:
	var stacks: Array = battle.get("stacks", [])
	for index in range(stacks.size() - 1, -1, -1):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("battle_id", "")) == battle_id:
			stacks.remove_at(index)
	battle["stacks"] = stacks

func _enemy_stack_ids_except_for_test(battle: Dictionary, retained_battle_id: String) -> Array[String]:
	var ids: Array[String] = []
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var battle_id := String(stack.get("battle_id", ""))
		if String(stack.get("side", "")) == "enemy" and battle_id != retained_battle_id:
			ids.append(battle_id)
	return ids

func _stack_hex_for_test(stack: Dictionary) -> Dictionary:
	var hex = stack.get("hex", {})
	return hex.duplicate(true) if hex is Dictionary else {}

func _set_stack_hex_for_test(battle: Dictionary, battle_id: String, hex: Dictionary) -> void:
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary) or String(stack.get("battle_id", "")) != battle_id:
			continue
		stack["hex"] = {"q": int(hex.get("q", 0)), "r": int(hex.get("r", 0))}
		stacks[index] = stack
		break
	battle["stacks"] = stacks

func _set_stack_health_for_test(battle: Dictionary, battle_id: String, total_health: int) -> void:
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary) or String(stack.get("battle_id", "")) != battle_id:
			continue
		stack["total_health"] = max(1, total_health)
		stack["count"] = max(1, int(stack.get("count", 1)))
		stacks[index] = stack
		break
	battle["stacks"] = stacks

func _set_stack_combat_profile_for_test(
	battle: Dictionary,
	battle_id: String,
	speed: int,
	ranged: bool,
	abilities: Array
) -> void:
	var stacks = battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary) or String(stack.get("battle_id", "")) != battle_id:
			continue
		stack["speed"] = max(1, speed)
		stack["ranged"] = ranged
		stack["shots_remaining"] = max(1, int(stack.get("shots_remaining", 1))) if ranged else 0
		stack["abilities"] = abilities.duplicate(true)
		stacks[index] = stack
		break
	battle["stacks"] = stacks

func _hex_key_for_test(hex: Dictionary) -> String:
	return "%d,%d" % [int(hex.get("q", -1)), int(hex.get("r", -1))]

func _stage_later_attack_destination_for_test(battle: Dictionary, player_id: String, target_id: String) -> Dictionary:
	var active_stack := _battle_stack_by_id(battle, player_id)
	if active_stack.is_empty():
		return {}
	var active_hex := _stack_hex_for_test(active_stack)
	for destination_value in BattleRules.legal_destinations_for_active_stack(battle):
		if not (destination_value is Dictionary):
			continue
		var destination: Dictionary = destination_value
		for neighbor_value in BattleRules._hex_neighbors(destination):
			if not (neighbor_value is Dictionary):
				continue
			var target_hex: Dictionary = neighbor_value
			if _hex_key_for_test(target_hex) == _hex_key_for_test(active_hex):
				continue
			if _hex_occupied_by_other_for_test(battle, target_id, target_hex):
				continue
			_set_stack_hex_for_test(battle, target_id, target_hex)
			battle["selected_target_id"] = target_id
			var selected_legality: Dictionary = BattleRules.selected_target_legality(battle)
			if not bool(selected_legality.get("blocked", false)):
				continue
			var intent: Dictionary = BattleRules.movement_intent_for_destination(
				battle,
				int(destination.get("q", -1)),
				int(destination.get("r", -1))
			)
			if bool(intent.get("sets_up_selected_target_attack", false)):
				return {
					"destination": destination,
					"target_hex": target_hex,
					"intent": intent,
				}
	return {}

func _open_neighbor_for_test(battle: Dictionary, origin: Dictionary, forbidden_keys: Array = []) -> Dictionary:
	for neighbor_value in BattleRules._hex_neighbors(origin):
		if not (neighbor_value is Dictionary):
			continue
		var neighbor: Dictionary = neighbor_value
		var key := _hex_key_for_test(neighbor)
		if key in forbidden_keys:
			continue
		if _hex_occupied_by_other_for_test(battle, "", neighbor):
			continue
		return neighbor
	return {}

func _far_open_hex_for_test(battle: Dictionary, origin: Dictionary, min_distance: int) -> Dictionary:
	var candidates := [
		{"q": 0, "r": 0},
		{"q": 0, "r": 6},
		{"q": 10, "r": 0},
		{"q": 10, "r": 6},
		{"q": 1, "r": 3},
		{"q": 9, "r": 3},
	]
	for candidate in candidates:
		if BattleRules._hex_distance(candidate, origin) < min_distance:
			continue
		if _hex_occupied_by_other_for_test(battle, "", candidate):
			continue
		return candidate
	return {}

func _hex_occupied_by_other_for_test(battle: Dictionary, allowed_battle_id: String, hex: Dictionary) -> bool:
	var key := _hex_key_for_test(hex)
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		if String(stack.get("battle_id", "")) == allowed_battle_id:
			continue
		if int(stack.get("total_health", 0)) <= 0:
			continue
		if _hex_key_for_test(_stack_hex_for_test(stack)) == key:
			return true
	return false

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

func _encounter_by_id(session, encounter_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("encounter_id", "")) == encounter_id:
			return encounter
	return {}

func _substring_count(text: String, needle: String) -> int:
	if needle == "":
		return 0
	var count := 0
	var offset := text.find(needle)
	while offset >= 0:
		count += 1
		offset = text.find(needle, offset + needle.length())
	return count

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

func _diagonal_open_tile(session, start: Vector2i) -> Vector2i:
	var map_size: Vector2i = OverworldRules.derive_map_size(session)
	for offset in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var tile: Vector2i = start + offset
		if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
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
