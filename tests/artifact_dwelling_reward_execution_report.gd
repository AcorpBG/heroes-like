extends Node

const REPORT_ID := "ARTIFACT_DWELLING_REWARD_EXECUTION_REPORT"
const PLAYER_SCENARIO_ID := "mireford-skirmish"
const NINEFOLD_SCENARIO_ID := "ninefold-confluence"
const PLAYER_PLACEMENT_ID := "graftroot_rootwatch_hollow"
const NINEFOLD_PLACEMENT_ID := "dwelling_greenbranch_copse"
const GREENBRANCH_SITE_ID := "site_greenbranch_copse"
const DWELLING_TABLE_ID := "artifact_source_dwelling_support_rare"
const ARTIFACT_ID := "artifact_living_bridge_knot"
const CUDGEL_ID := "unit_neutral_greenbranch_cudgels"
const CALLER_ID := "unit_neutral_sapwhistle_callers"
const AI_FACTION_ID := "faction_thornwake"
const SAVE_SLOT := 7

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_case := _player_claim_case()
	if player_case.is_empty():
		return
	var ineligible_case := _ineligible_player_case()
	if ineligible_case.is_empty():
		return
	var ai_case := _ai_claim_case()
	if ai_case.is_empty():
		return
	var ai_route_case := _ai_route_claim_case()
	if ai_route_case.is_empty():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"report_id": REPORT_ID,
		"player_case": player_case,
		"ineligible_case": ineligible_case,
		"ai_case": ai_case,
		"ai_route_case": ai_route_case,
		"save_version": SessionStateStore.SAVE_VERSION,
		"runtime_policy": {
			"thornwake_dwelling_table_live": true,
			"player_and_ai_claims": true,
			"one_time_reward": true,
			"dwelling_recruits_preserved": true,
			"persistent_control_preserved": true,
			"save_version_bump": false,
		},
	})])
	get_tree().quit(0)

func _player_claim_case() -> Dictionary:
	var session = _session(PLAYER_SCENARIO_ID)
	var hero: Dictionary = session.overworld.get("hero", {})
	if ARTIFACT_ID in ArtifactRules.owned_artifact_ids(hero):
		_fail("Mireford fixture already owns the dwelling artifact.")
		return {}
	var army_before: Dictionary = session.overworld.get("army", {})
	var cudgels_before := _stack_count(army_before.get("stacks", []), CUDGEL_ID)
	var callers_before := _stack_count(army_before.get("stacks", []), CALLER_ID)
	var claim := OverworldRules._collect_resource_node_result(
		session,
		_resource_node_result(session, PLAYER_PLACEMENT_ID),
		false
	)
	if not bool(claim.get("ok", false)):
		_fail("Thornwake Rootwatch Hollow claim failed: %s" % JSON.stringify(claim))
		return {}
	var node: Dictionary = _resource_node_result(session, PLAYER_PLACEMENT_ID).get("node", {})
	hero = session.overworld.get("hero", {})
	var army_after: Dictionary = session.overworld.get("army", {})
	if String(node.get("collected_by_faction_id", "")) != "player" \
			or String(node.get("artifact_reward_id", "")) != ARTIFACT_ID \
			or String(node.get("artifact_reward_table_id", "")) != DWELLING_TABLE_ID \
			or String(node.get("artifact_reward_claimed_by_faction_id", "")) != "player":
		_fail("Rootwatch Hollow control or artifact provenance is incomplete: %s" % JSON.stringify(node))
		return {}
	if ARTIFACT_ID not in ArtifactRules.owned_artifact_ids(hero) or not _artifact_equipped(hero, ARTIFACT_ID):
		_fail("Thornwake hero did not receive and equip Living Bridge Knot: %s" % JSON.stringify(hero.get("artifacts", {})))
		return {}
	if _stack_count(army_after.get("stacks", []), CUDGEL_ID) != cudgels_before + 3 \
			or _stack_count(army_after.get("stacks", []), CALLER_ID) != callers_before + 1:
		_fail("Rootwatch Hollow artifact reward displaced its dwelling recruits: %s" % JSON.stringify(army_after))
		return {}

	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	var restored = SaveService.restore_manual_session(SAVE_SLOT)
	if not bool(save_result.get("ok", false)) or restored == null:
		_fail("Rootwatch Hollow reward did not save and restore: %s" % JSON.stringify(save_result))
		return {}
	OverworldRules.normalize_overworld_state(restored)
	var restored_node: Dictionary = _resource_node_result(restored, PLAYER_PLACEMENT_ID).get("node", {})
	var restored_hero: Dictionary = restored.overworld.get("hero", {})
	var restored_army: Dictionary = restored.overworld.get("army", {})
	if int(restored.save_version) != int(SessionStateStore.SAVE_VERSION) \
			or String(restored_node.get("collected_by_faction_id", "")) != "player" \
			or String(restored_node.get("artifact_reward_id", "")) != ARTIFACT_ID \
			or ARTIFACT_ID not in ArtifactRules.owned_artifact_ids(restored_hero) \
			or not _artifact_equipped(restored_hero, ARTIFACT_ID) \
			or _stack_count(restored_army.get("stacks", []), CUDGEL_ID) != cudgels_before + 3 \
			or _stack_count(restored_army.get("stacks", []), CALLER_ID) != callers_before + 1:
		_fail("Rootwatch Hollow dwelling reward state changed across save/resume.")
		return {}

	_set_node_controller(restored, PLAYER_PLACEMENT_ID, AI_FACTION_ID)
	var owned_before_recapture := ArtifactRules.owned_artifact_ids(restored_hero)
	var provenance_before := _artifact_provenance(_resource_node_result(restored, PLAYER_PLACEMENT_ID).get("node", {}))
	var recapture := OverworldRules._collect_resource_node_result(
		restored,
		_resource_node_result(restored, PLAYER_PLACEMENT_ID),
		false
	)
	var recaptured_node: Dictionary = _resource_node_result(restored, PLAYER_PLACEMENT_ID).get("node", {})
	if not bool(recapture.get("ok", false)) \
			or String(recaptured_node.get("collected_by_faction_id", "")) != "player" \
			or ArtifactRules.owned_artifact_ids(restored.overworld.get("hero", {})) != owned_before_recapture \
			or _artifact_provenance(recaptured_node) != provenance_before:
		_fail("Rootwatch Hollow recapture did not preserve one-time provenance: %s" % JSON.stringify(recapture))
		return {}
	return {
		"artifact_id": ARTIFACT_ID,
		"table_id": DWELLING_TABLE_ID,
		"auto_equipped": true,
		"claim_recruits": {CUDGEL_ID: 3, CALLER_ID: 1},
		"persistent_control": true,
		"save_resume_preserved": true,
		"recapture_reward_blocked": true,
	}

func _ineligible_player_case() -> Dictionary:
	var session = _session(NINEFOLD_SCENARIO_ID)
	var army_before: Dictionary = session.overworld.get("army", {})
	var cudgels_before := _stack_count(army_before.get("stacks", []), CUDGEL_ID)
	var callers_before := _stack_count(army_before.get("stacks", []), CALLER_ID)
	var owned_before := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	var claim := OverworldRules._collect_resource_node_result(
		session,
		_resource_node_result(session, NINEFOLD_PLACEMENT_ID),
		false
	)
	if not bool(claim.get("ok", false)):
		_fail("Ineligible Embercourt Greenbranch Copse claim failed: %s" % JSON.stringify(claim))
		return {}
	var node: Dictionary = _resource_node_result(session, NINEFOLD_PLACEMENT_ID).get("node", {})
	var army_after: Dictionary = session.overworld.get("army", {})
	if String(node.get("collected_by_faction_id", "")) != "player" \
			or String(node.get("artifact_reward_id", "")) != "" \
			or ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {})) != owned_before:
		_fail("Ineligible Embercourt dwelling claim received an artifact: %s" % JSON.stringify(node))
		return {}
	if _stack_count(army_after.get("stacks", []), CUDGEL_ID) != cudgels_before + 2 \
			or _stack_count(army_after.get("stacks", []), CALLER_ID) != callers_before + 1:
		_fail("Artifact faction gating blocked normal Greenbranch recruits: %s" % JSON.stringify(army_after))
		return {}
	return {
		"faction_id": "faction_embercourt",
		"artifact_reward_blocked": true,
		"persistent_control": true,
		"claim_recruits": {CUDGEL_ID: 2, CALLER_ID: 1},
	}

func _ai_claim_case() -> Dictionary:
	var session = _session(NINEFOLD_SCENARIO_ID)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	_set_node_controller(session, NINEFOLD_PLACEMENT_ID, "player")
	var state := _enemy_state(session, AI_FACTION_ID)
	var roster: Array = state.get("commander_roster", []) if state.get("commander_roster", []) is Array else []
	if roster.is_empty():
		_fail("Ninefold Thornwake has no commander roster for dwelling reward execution.")
		return {}
	var node: Dictionary = _resource_node_result(session, NINEFOLD_PLACEMENT_ID).get("node", {})
	var raid := _raid_fixture(session, node, roster[0], "dwelling_reward_ai_raid", "resource")
	var army_before: Dictionary = raid.get("enemy_army", {})
	var cudgels_before := _stack_count(army_before.get("stacks", []), CUDGEL_ID)
	var callers_before := _stack_count(army_before.get("stacks", []), CALLER_ID)
	var secured := EnemyAdventureRules._secure_resource_target(session, raid, state, AI_FACTION_ID)
	var reward: Dictionary = secured.get("artifact_reward", {}) if secured.get("artifact_reward", {}) is Dictionary else {}
	var secured_raid: Dictionary = secured.get("encounter", {}) if secured.get("encounter", {}) is Dictionary else {}
	var commander: Dictionary = secured_raid.get("enemy_commander_state", {}) if secured_raid.get("enemy_commander_state", {}) is Dictionary else {}
	var army_after: Dictionary = secured_raid.get("enemy_army", {}) if secured_raid.get("enemy_army", {}) is Dictionary else {}
	if not bool(reward.get("applied", false)) \
			or String(reward.get("artifact_id", "")) != ARTIFACT_ID \
			or ARTIFACT_ID not in ArtifactRules.owned_artifact_ids(commander) \
			or not _artifact_equipped(commander, ARTIFACT_ID):
		_fail("Thornwake AI commander did not receive and equip the dwelling artifact: %s" % JSON.stringify(secured))
		return {}
	if _stack_count(army_after.get("stacks", []), CUDGEL_ID) != cudgels_before + 2 \
			or _stack_count(army_after.get("stacks", []), CALLER_ID) != callers_before + 1:
		_fail("Thornwake AI dwelling artifact displaced claim recruits: %s" % JSON.stringify(army_after))
		return {}
	var secured_node: Dictionary = _resource_node_result(session, NINEFOLD_PLACEMENT_ID).get("node", {})
	if String(secured_node.get("collected_by_faction_id", "")) != AI_FACTION_ID \
			or String(secured_node.get("artifact_reward_claimed_by_faction_id", "")) != AI_FACTION_ID \
			or String(secured_node.get("artifact_reward_id", "")) != ARTIFACT_ID:
		_fail("Thornwake AI dwelling control or provenance was not persisted: %s" % JSON.stringify(secured_node))
		return {}
	if ARTIFACT_ID not in (secured.get("state", {}) as Dictionary).get("captured_artifact_ids", []):
		_fail("Thornwake empire state did not track the dwelling artifact.")
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(secured.get("ai_events", []), 4)
	if not bool(public_log.get("ok", false)):
		_fail("AI dwelling reward event crossed the public-log boundary: %s" % JSON.stringify(public_log))
		return {}
	return {
		"faction_id": AI_FACTION_ID,
		"artifact_id": ARTIFACT_ID,
		"auto_equipped": true,
		"claim_recruits_preserved": true,
		"persistent_control": true,
		"captured_artifact_tracked": true,
		"public_event_boundary": true,
	}

func _ai_route_claim_case() -> Dictionary:
	var session = _session(NINEFOLD_SCENARIO_ID)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	_set_node_controller(session, NINEFOLD_PLACEMENT_ID, "player")
	var state := _enemy_state(session, AI_FACTION_ID)
	var roster: Array = state.get("commander_roster", []) if state.get("commander_roster", []) is Array else []
	if roster.is_empty():
		_fail("Ninefold Thornwake has no commander roster for route dwelling execution.")
		return {}
	var node_result := _resource_node_result(session, NINEFOLD_PLACEMENT_ID)
	var node: Dictionary = node_result.get("node", {})
	var raid := _raid_fixture(session, node, roster[0], "dwelling_reward_route_ai_raid", "town")
	var army_before: Dictionary = raid.get("enemy_army", {})
	var cudgels_before := _stack_count(army_before.get("stacks", []), CUDGEL_ID)
	var callers_before := _stack_count(army_before.get("stacks", []), CALLER_ID)
	var secured := EnemyAdventureRules._secure_opportunistic_route_resource(
		session,
		{"faction_id": AI_FACTION_ID, "label": "Graftroot Concord"},
		raid,
		state,
		AI_FACTION_ID,
		int(node_result.get("index", -1)),
		node,
		ContentService.get_resource_site(GREENBRANCH_SITE_ID)
	)
	var reward: Dictionary = secured.get("artifact_reward", {}) if secured.get("artifact_reward", {}) is Dictionary else {}
	var secured_raid: Dictionary = secured.get("encounter", {}) if secured.get("encounter", {}) is Dictionary else {}
	var commander: Dictionary = secured_raid.get("enemy_commander_state", {}) if secured_raid.get("enemy_commander_state", {}) is Dictionary else {}
	var army_after: Dictionary = secured_raid.get("enemy_army", {}) if secured_raid.get("enemy_army", {}) is Dictionary else {}
	var secured_node: Dictionary = _resource_node_result(session, NINEFOLD_PLACEMENT_ID).get("node", {})
	if not bool(secured.get("resolved", false)) \
			or not bool(reward.get("applied", false)) \
			or String(reward.get("artifact_id", "")) != ARTIFACT_ID \
			or ARTIFACT_ID not in ArtifactRules.owned_artifact_ids(commander) \
			or String(secured_node.get("artifact_reward_id", "")) != ARTIFACT_ID \
			or String(secured_node.get("collected_by_faction_id", "")) != AI_FACTION_ID:
		_fail("Thornwake opportunistic dwelling claim did not apply the artifact reward: %s" % JSON.stringify(secured))
		return {}
	if _stack_count(army_after.get("stacks", []), CUDGEL_ID) != cudgels_before + 2 \
			or _stack_count(army_after.get("stacks", []), CALLER_ID) != callers_before + 1:
		_fail("Thornwake opportunistic dwelling claim displaced recruits: %s" % JSON.stringify(army_after))
		return {}
	return {
		"artifact_id": ARTIFACT_ID,
		"route_claim_resolved": true,
		"commander_rewarded": true,
		"claim_recruits_preserved": true,
		"persistent_control": true,
		"provenance_preserved": true,
	}

func _session(scenario_id: String):
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	return session

func _resource_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
	for index in range(nodes.size()):
		var node = nodes[index]
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

func _set_node_controller(session, placement_id: String, faction_id: String) -> void:
	var result := _resource_node_result(session, placement_id)
	var index := int(result.get("index", -1))
	if index < 0:
		return
	var nodes: Array = session.overworld.get("resource_nodes", [])
	var node: Dictionary = result.get("node", {}).duplicate(true)
	node["collected"] = faction_id != ""
	node["collected_by_faction_id"] = faction_id
	nodes[index] = node
	session.overworld["resource_nodes"] = nodes

func _enemy_state(session, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state
	return {}

func _raid_fixture(session, node: Dictionary, roster_entry: Dictionary, placement_id: String, target_kind: String) -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_graftroot_wardens",
		"spawned_by_faction_id": AI_FACTION_ID,
		"target_kind": target_kind,
		"target_placement_id": NINEFOLD_PLACEMENT_ID if target_kind == "resource" else "riverwatch_hold",
		"target_x": int(node.get("x", 0)),
		"target_y": int(node.get("y", 0)),
		"goal_x": int(node.get("x", 0)),
		"goal_y": int(node.get("y", 0)),
		"x": int(node.get("x", 0)),
		"y": int(node.get("y", 0)),
		"enemy_commander_state": roster_entry.get("commander_state", {}).duplicate(true),
		"target_reason_codes": ["artifact_dwelling_reward_fixture"],
	}
	return EnemyAdventureRules.ensure_raid_army(raid, session)

func _artifact_equipped(hero: Dictionary, artifact_id: String) -> bool:
	var artifacts: Dictionary = hero.get("artifacts", {}) if hero.get("artifacts", {}) is Dictionary else {}
	var equipped: Dictionary = artifacts.get("equipped", {}) if artifacts.get("equipped", {}) is Dictionary else {}
	return artifact_id in equipped.values()

func _artifact_provenance(node: Dictionary) -> Dictionary:
	return {
		"artifact_reward_id": String(node.get("artifact_reward_id", "")),
		"artifact_reward_table_id": String(node.get("artifact_reward_table_id", "")),
		"artifact_reward_source_key": String(node.get("artifact_reward_source_key", "")),
		"artifact_reward_claimed_by_faction_id": String(node.get("artifact_reward_claimed_by_faction_id", "")),
		"artifact_reward_claimed_day": int(node.get("artifact_reward_claimed_day", 0)),
	}

func _stack_count(stacks: Variant, unit_id: String) -> int:
	if not (stacks is Array):
		return 0
	for stack in stacks:
		if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
			return int(stack.get("count", 0))
	return 0

func _fail(message: String) -> void:
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
