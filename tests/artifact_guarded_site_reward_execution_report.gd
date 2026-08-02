extends Node

const REPORT_ID := "ARTIFACT_GUARDED_SITE_REWARD_EXECUTION_REPORT"
const SCENARIO_ID := "ninefold-confluence"
const BARROW_ID := "barrow_vault"
const RELIQUARY_ID := "drowned_reliquary"
const AI_FACTION_ID := "faction_mireclaw"
const SAVE_SLOT := 2

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_case := _player_reward_case()
	if player_case.is_empty():
		return
	var ai_case := _ai_reward_case()
	if ai_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"player_case": player_case,
		"ai_case": ai_case,
		"save_version": SessionStateStore.SAVE_VERSION,
		"runtime_policy": {
			"guarded_site_table_live": true,
			"player_and_ai_claims": true,
			"guard_clearance_required": true,
			"save_version_bump": false,
		},
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _player_reward_case() -> Dictionary:
	var session = _session()
	var barrow := _resource_node_result(session, BARROW_ID)
	var guard := OverworldRules.resource_site_blocking_guard(
		session,
		barrow.get("node", {}),
		ContentService.get_resource_site("site_barrow_vault")
	)
	if guard.is_empty():
		_fail("Ninefold Barrow Vault has no live guard encounter.")
		return {}
	var blocked := OverworldRules._collect_resource_node_result(session, barrow, false)
	if bool(blocked.get("ok", true)) or not String(blocked.get("message", "")).begins_with("Clear "):
		_fail("Player claimed Barrow Vault before clearing its guard: %s" % JSON.stringify(blocked))
		return {}
	_resolve_guard(session, guard)
	var owned_before := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	var claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, BARROW_ID), false)
	if not bool(claim.get("ok", false)):
		_fail("Player Barrow Vault claim failed after guard clearance: %s" % JSON.stringify(claim))
		return {}
	var owned_after := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	if owned_after.size() != owned_before.size() + 1:
		_fail("Player guarded-site claim did not add exactly one artifact: %s" % JSON.stringify(owned_after))
		return {}
	var barrow_node: Dictionary = _resource_node_result(session, BARROW_ID).get("node", {})
	var first_artifact_id := String(barrow_node.get("artifact_reward_id", ""))
	if first_artifact_id == "" or String(barrow_node.get("artifact_reward_claimed_by_faction_id", "")) != "player":
		_fail("Player Barrow Vault provenance was not persisted: %s" % JSON.stringify(barrow_node))
		return {}

	var reliquary := _resource_node_result(session, RELIQUARY_ID)
	var reliquary_guard := OverworldRules.resource_site_blocking_guard(
		session,
		reliquary.get("node", {}),
		ContentService.get_resource_site("site_drowned_reliquary")
	)
	if reliquary_guard.is_empty():
		_fail("Ninefold Drowned Reliquary has no live guard encounter.")
		return {}
	_resolve_guard(session, reliquary_guard)
	var second_claim := OverworldRules._collect_resource_node_result(session, _resource_node_result(session, RELIQUARY_ID), false)
	if not bool(second_claim.get("ok", false)):
		_fail("Player Drowned Reliquary claim failed after guard clearance: %s" % JSON.stringify(second_claim))
		return {}
	var reliquary_node: Dictionary = _resource_node_result(session, RELIQUARY_ID).get("node", {})
	var second_artifact_id := String(reliquary_node.get("artifact_reward_id", ""))
	if second_artifact_id == "" or second_artifact_id == first_artifact_id:
		_fail("Two guarded sites did not grant distinct eligible artifacts: %s / %s" % [first_artifact_id, second_artifact_id])
		return {}

	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	var restored = SaveService.restore_manual_session(SAVE_SLOT)
	if not bool(save_result.get("ok", false)) or restored == null:
		_fail("Guarded-site player state did not save and restore: %s" % JSON.stringify(save_result))
		return {}
	OverworldRules.normalize_overworld_state(restored)
	var restored_barrow: Dictionary = _resource_node_result(restored, BARROW_ID).get("node", {})
	var restored_reliquary: Dictionary = _resource_node_result(restored, RELIQUARY_ID).get("node", {})
	var restored_owned := ArtifactRules.owned_artifact_ids(restored.overworld.get("hero", {}))
	if first_artifact_id not in restored_owned or second_artifact_id not in restored_owned:
		_fail("Restored hero lost guarded-site artifacts: %s" % JSON.stringify(restored_owned))
		return {}
	if String(restored_barrow.get("artifact_reward_id", "")) != first_artifact_id or String(restored_reliquary.get("artifact_reward_id", "")) != second_artifact_id:
		_fail("Restored guarded-site nodes lost artifact provenance.")
		return {}
	var repeat := OverworldRules._collect_resource_node_result(restored, _resource_node_result(restored, BARROW_ID), false)
	if bool(repeat.get("ok", true)) or ArtifactRules.owned_artifact_ids(restored.overworld.get("hero", {})).size() != restored_owned.size():
		_fail("Restored Barrow Vault granted a repeated artifact reward: %s" % JSON.stringify(repeat))
		return {}
	return {
		"blocked_before_guard_clear": true,
		"first_artifact_id": first_artifact_id,
		"second_artifact_id": second_artifact_id,
		"distinct_rewards": true,
		"save_resume_preserved": true,
		"repeat_claim_blocked": true,
	}

func _ai_reward_case() -> Dictionary:
	var session = _session()
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var state := _enemy_state(session, AI_FACTION_ID)
	if state.is_empty():
		_fail("Ninefold has no Mireclaw enemy state.")
		return {}
	var roster: Array = state.get("commander_roster", []) if state.get("commander_roster", []) is Array else []
	if roster.is_empty():
		_fail("Mireclaw has no commander roster for guarded-site reward execution.")
		return {}
	var commander_state: Dictionary = roster[0].get("commander_state", {}).duplicate(true)
	var node_result := _resource_node_result(session, BARROW_ID)
	var node: Dictionary = node_result.get("node", {})
	var raid := {
		"placement_id": "guarded_site_reward_ai_raid",
		"encounter_id": "encounter_mire_raid",
		"spawned_by_faction_id": AI_FACTION_ID,
		"target_kind": "resource",
		"target_placement_id": BARROW_ID,
		"target_x": int(node.get("x", 0)),
		"target_y": int(node.get("y", 0)),
		"goal_x": int(node.get("x", 0)),
		"goal_y": int(node.get("y", 0)),
		"x": int(node.get("x", 0)),
		"y": int(node.get("y", 0)),
		"enemy_commander_state": commander_state,
		"target_reason_codes": ["artifact_reward_fixture"],
	}
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	var blocked := EnemyAdventureRules._secure_resource_target(session, raid, state, AI_FACTION_ID)
	if String(blocked.get("event_message", "")) != "" or String(_resource_node_result(session, BARROW_ID).get("node", {}).get("collected_by_faction_id", "")) != "":
		_fail("AI claimed Barrow Vault before guard clearance: %s" % JSON.stringify(blocked))
		return {}
	var guard := OverworldRules.resource_site_blocking_guard(
		session,
		node,
		ContentService.get_resource_site("site_barrow_vault")
	)
	_resolve_guard(session, guard)
	var secured := EnemyAdventureRules._secure_resource_target(session, raid, state, AI_FACTION_ID)
	var reward: Dictionary = secured.get("artifact_reward", {}) if secured.get("artifact_reward", {}) is Dictionary else {}
	var artifact_id := String(reward.get("artifact_id", ""))
	var secured_raid: Dictionary = secured.get("encounter", {}) if secured.get("encounter", {}) is Dictionary else {}
	var secured_commander: Dictionary = secured_raid.get("enemy_commander_state", {}) if secured_raid.get("enemy_commander_state", {}) is Dictionary else {}
	if not bool(reward.get("applied", false)) or artifact_id == "" or artifact_id not in ArtifactRules.owned_artifact_ids(secured_commander):
		_fail("AI commander did not receive guarded-site artifact: %s" % JSON.stringify(secured))
		return {}
	var secured_node: Dictionary = _resource_node_result(session, BARROW_ID).get("node", {})
	if String(secured_node.get("artifact_reward_claimed_by_faction_id", "")) != AI_FACTION_ID or String(secured_node.get("artifact_reward_id", "")) != artifact_id:
		_fail("AI guarded-site provenance was not persisted: %s" % JSON.stringify(secured_node))
		return {}
	if artifact_id not in (secured.get("state", {}) as Dictionary).get("captured_artifact_ids", []):
		_fail("AI empire state did not track the guarded-site artifact: %s" % JSON.stringify(secured.get("state", {})))
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(secured.get("ai_events", []), 4)
	if not bool(public_log.get("ok", false)):
		_fail("AI guarded-site reward event crossed the public-log boundary: %s" % JSON.stringify(public_log))
		return {}
	return {
		"blocked_before_guard_clear": true,
		"artifact_id": artifact_id,
		"commander_auto_equipped": bool(reward.get("claim", {}).get("auto_equipped", false)),
		"provenance_preserved": true,
		"captured_artifact_tracked": true,
		"public_event_boundary": true,
	}

func _session():
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	return session

func _resource_node_result(session, placement_id: String) -> Dictionary:
	var nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
	for index in range(nodes.size()):
		var node = nodes[index]
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return {"index": index, "node": node}
	return {"index": -1, "node": {}}

func _resolve_guard(session, guard: Dictionary) -> void:
	var placement_id := String(guard.get("placement_id", guard.get("id", "")))
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	if placement_id != "" and placement_id not in resolved:
		resolved.append(placement_id)
	session.overworld["resolved_encounters"] = resolved

func _enemy_state(session, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state
	return {}

func _fail(message: String) -> void:
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
