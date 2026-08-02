extends Node

const REPORT_ID := "ARTIFACT_PICKUP_SOURCE_EXECUTION_REPORT"
const TABLE_ID := "artifact_source_pickup_caches_common"
const MIRE_SCENARIO_ID := "mireford-skirmish"
const OREVEIN_SCENARIO_ID := "orevein-contract"
const FIXED_SCENARIO_ID := "bellwake-wreck-claim"
const MIRE_PLACEMENT_ID := "bridge_boots"
const OREVEIN_PLACEMENT_ID := "orevein_trailsinger_boots"
const FIXED_PLACEMENT_ID := "bellwake_waymark_compass"
const BOOTS_ID := "artifact_trailsinger_boots"
const ROD_ID := "artifact_quarry_tally_rod"
const FIXED_ARTIFACT_ID := "artifact_waymark_compass"
const AI_FACTION_ID := "faction_mireclaw"
const SAVE_SLOT := 3

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var materialization_case := _materialization_case()
	if materialization_case.is_empty():
		return
	var player_case := _player_claim_and_save_case()
	if player_case.is_empty():
		return
	var ai_case := _ai_claim_case(false)
	if ai_case.is_empty():
		return
	var ai_route_case := _ai_claim_case(true)
	if ai_route_case.is_empty():
		return
	var fixed_case := _fixed_pickup_case()
	if fixed_case.is_empty():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"report_id": REPORT_ID,
		"materialization_case": materialization_case,
		"player_case": player_case,
		"ai_case": ai_case,
		"ai_route_case": ai_route_case,
		"fixed_case": fixed_case,
		"save_version": SessionStateStore.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _materialization_case() -> Dictionary:
	var mire_session = _session(MIRE_SCENARIO_ID)
	var orevein_session = _session(OREVEIN_SCENARIO_ID)
	var mire_node: Dictionary = _artifact_node_result(mire_session, MIRE_PLACEMENT_ID).get("node", {})
	var orevein_node: Dictionary = _artifact_node_result(orevein_session, OREVEIN_PLACEMENT_ID).get("node", {})
	if not _assert_materialized_node(mire_node, MIRE_SCENARIO_ID, MIRE_PLACEMENT_ID, BOOTS_ID):
		return {}
	if not _assert_materialized_node(orevein_node, OREVEIN_SCENARIO_ID, OREVEIN_PLACEMENT_ID, ROD_ID):
		return {}

	OverworldRules.normalize_overworld_state(mire_session)
	OverworldRules.normalize_overworld_state(mire_session)
	var normalized_node: Dictionary = _artifact_node_result(mire_session, MIRE_PLACEMENT_ID).get("node", {})
	if normalized_node != mire_node:
		_fail("Repeated normalization changed a materialized pickup: %s" % JSON.stringify(normalized_node))
		return {}
	return {
		"table_id": TABLE_ID,
		"mire_artifact_id": String(mire_node.get("artifact_id", "")),
		"orevein_artifact_id": String(orevein_node.get("artifact_id", "")),
		"normalization_stable": true,
	}

func _player_claim_and_save_case() -> Dictionary:
	var session = _session(OREVEIN_SCENARIO_ID)
	var node_result := _artifact_node_result(session, OREVEIN_PLACEMENT_ID)
	var claim := OverworldRules._collect_artifact_node_result(session, node_result, false)
	if not bool(claim.get("ok", false)):
		_fail("Player pickup claim failed: %s" % JSON.stringify(claim))
		return {}
	var claimed_node: Dictionary = _artifact_node_result(session, OREVEIN_PLACEMENT_ID).get("node", {})
	var hero: Dictionary = session.overworld.get("hero", {})
	if not bool(claimed_node.get("collected", false)) \
			or String(claimed_node.get("collected_by_faction_id", "")) != "player" \
			or not _assert_materialized_node(claimed_node, OREVEIN_SCENARIO_ID, OREVEIN_PLACEMENT_ID, ROD_ID) \
			or ROD_ID not in ArtifactRules.owned_artifact_ids(hero) \
			or not _artifact_equipped(hero, ROD_ID):
		_fail("Player claim did not preserve pickup provenance and equipment: %s" % JSON.stringify(claimed_node))
		return {}
	var duplicate_claim := OverworldRules._collect_artifact_node_result(
		session,
		_artifact_node_result(session, OREVEIN_PLACEMENT_ID),
		false
	)
	if bool(duplicate_claim.get("ok", true)):
		_fail("Collected pickup could be claimed twice: %s" % JSON.stringify(duplicate_claim))
		return {}

	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	var restored = SaveService.restore_manual_session(SAVE_SLOT)
	if not bool(save_result.get("ok", false)) or restored == null:
		_fail("Materialized pickup did not save and restore: %s" % JSON.stringify(save_result))
		return {}
	OverworldRules.normalize_overworld_state(restored)
	OverworldRules.normalize_overworld_state(restored)
	var restored_node: Dictionary = _artifact_node_result(restored, OREVEIN_PLACEMENT_ID).get("node", {})
	var restored_hero: Dictionary = restored.overworld.get("hero", {})
	if restored_node != claimed_node \
			or ROD_ID not in ArtifactRules.owned_artifact_ids(restored_hero) \
			or not _artifact_equipped(restored_hero, ROD_ID):
		_fail("Pickup selection, collection, or equipment changed across save/resume: %s" % JSON.stringify(restored_node))
		return {}
	return {
		"artifact_id": ROD_ID,
		"auto_equipped": true,
		"one_time_collection": true,
		"save_resume_preserved": true,
	}

func _ai_claim_case(opportunistic_route: bool) -> Dictionary:
	var session = _session(MIRE_SCENARIO_ID)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var state := _enemy_state(session, AI_FACTION_ID)
	var roster: Array = state.get("commander_roster", []) if state.get("commander_roster", []) is Array else []
	if roster.is_empty():
		_fail("Mireford has no Mireclaw commander roster for pickup execution.")
		return {}
	var node_result := _artifact_node_result(session, MIRE_PLACEMENT_ID)
	var node: Dictionary = node_result.get("node", {})
	var raid := {
		"placement_id": "pickup_route_raid" if opportunistic_route else "pickup_target_raid",
		"encounter_id": "encounter_mire_raid",
		"spawned_by_faction_id": AI_FACTION_ID,
		"target_kind": "town" if opportunistic_route else "artifact",
		"target_placement_id": "highwater_bridgehead" if opportunistic_route else MIRE_PLACEMENT_ID,
		"target_x": int(node.get("x", 0)),
		"target_y": int(node.get("y", 0)),
		"goal_x": int(node.get("x", 0)),
		"goal_y": int(node.get("y", 0)),
		"x": int(node.get("x", 0)),
		"y": int(node.get("y", 0)),
		"enemy_commander_state": roster[0].get("commander_state", {}).duplicate(true),
		"target_reason_codes": ["pickup_source_execution_fixture"],
	}
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	var config := _enemy_config(MIRE_SCENARIO_ID, AI_FACTION_ID)
	var secured := EnemyAdventureRules._secure_opportunistic_route_artifact(
		session,
		config,
		raid,
		state,
		AI_FACTION_ID,
		int(node_result.get("index", -1)),
		node
	) if opportunistic_route else EnemyAdventureRules._secure_artifact_target(
		session,
		raid,
		state,
		AI_FACTION_ID,
		config
	)
	var secured_raid: Dictionary = secured.get("encounter", {}) if secured.get("encounter", {}) is Dictionary else {}
	var commander: Dictionary = secured_raid.get("enemy_commander_state", {}) if secured_raid.get("enemy_commander_state", {}) is Dictionary else {}
	var secured_node: Dictionary = _artifact_node_result(session, MIRE_PLACEMENT_ID).get("node", {})
	if not bool(secured_node.get("collected", false)) \
			or String(secured_node.get("collected_by_faction_id", "")) != AI_FACTION_ID \
			or not _assert_materialized_node(secured_node, MIRE_SCENARIO_ID, MIRE_PLACEMENT_ID, BOOTS_ID) \
			or BOOTS_ID not in ArtifactRules.owned_artifact_ids(commander) \
			or not _artifact_equipped(commander, BOOTS_ID) \
			or BOOTS_ID not in state.get("captured_artifact_ids", []):
		_fail("AI pickup claim did not preserve provenance, ownership, and equipment: %s" % JSON.stringify(secured))
		return {}
	return {
		"artifact_id": BOOTS_ID,
		"claim_mode": "opportunistic_route" if opportunistic_route else "assigned_target",
		"auto_equipped": true,
		"provenance_preserved": true,
	}

func _fixed_pickup_case() -> Dictionary:
	var session = _session(FIXED_SCENARIO_ID)
	var node: Dictionary = _artifact_node_result(session, FIXED_PLACEMENT_ID).get("node", {})
	if String(node.get("artifact_id", "")) != FIXED_ARTIFACT_ID \
			or node.has("artifact_reward_table_id") \
			or node.has("artifact_reward_source_key") \
			or node.has("artifact_source_materialized"):
		_fail("Non-opted fixed pickup changed behavior: %s" % JSON.stringify(node))
		return {}
	return {"artifact_id": FIXED_ARTIFACT_ID, "fixed_behavior_preserved": true}

func _session(scenario_id: String):
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	return session

func _artifact_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("artifact_nodes", []) if session.overworld.get("artifact_nodes", []) is Array else []
	for index in range(nodes.size()):
		var node = nodes[index]
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

func _enemy_state(session, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state
	return {}

func _enemy_config(scenario_id: String, faction_id: String) -> Dictionary:
	for config in ContentService.get_scenario(scenario_id).get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	return {"faction_id": faction_id, "label": faction_id}

func _assert_materialized_node(node: Dictionary, scenario_id: String, placement_id: String, artifact_id: String) -> bool:
	var expected_source_key := "%s:%s:pickup" % [scenario_id, placement_id]
	if String(node.get("artifact_id", "")) != artifact_id \
			or String(node.get("artifact_reward_table_id", "")) != TABLE_ID \
			or String(node.get("artifact_reward_source_key", "")) != expected_source_key \
			or not bool(node.get("artifact_source_materialized", false)):
		_fail("Pickup source did not materialize expected state: %s" % JSON.stringify(node))
		return false
	return true

func _artifact_equipped(hero: Dictionary, artifact_id: String) -> bool:
	var artifacts: Dictionary = hero.get("artifacts", {}) if hero.get("artifacts", {}) is Dictionary else {}
	var equipped: Dictionary = artifacts.get("equipped", {}) if artifacts.get("equipped", {}) is Dictionary else {}
	return artifact_id in equipped.values()

func _fail(message: String) -> void:
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
