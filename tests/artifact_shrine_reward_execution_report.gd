extends Node

const REPORT_ID := "ARTIFACT_SHRINE_REWARD_EXECUTION_REPORT"
const PLAYER_SCENARIO_ID := "prismhearth-watch"
const INELIGIBLE_SCENARIO_ID := "glassfen-breakers"
const AI_SCENARIO_ID := "ninefold-confluence"
const PLAYER_PLACEMENT_ID := "prismhearth_starlens"
const INELIGIBLE_PLACEMENT_ID := "glassfen_starlens"
const AI_PLACEMENT_ID := "starlens_sanctum"
const SHRINE_SITE_ID := "site_starlens_sanctum"
const SHRINE_TABLE_ID := "artifact_source_shrine_accord_rare"
const ARTIFACT_ID := "artifact_choir_tuning_fork"
const SPELL_ID := "spell_beacon_path"
const AI_FACTION_ID := "faction_sunvault"
const SAVE_SLOT := 6

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
			"starlens_shrine_table_live": true,
			"player_and_ai_claims": true,
			"one_time_reward": true,
			"faction_mapped_selection": true,
			"save_version_bump": false,
		},
	})])
	get_tree().quit(0)

func _player_claim_case() -> Dictionary:
	var session = _session(PLAYER_SCENARIO_ID)
	_remove_known_spell(session, SPELL_ID)
	var owned_before := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	if ARTIFACT_ID in owned_before:
		_fail("Prismhearth fixture already owns the shrine artifact.")
		return {}
	var claim := OverworldRules._collect_resource_node_result(
		session,
		_resource_node_result(session, PLAYER_PLACEMENT_ID),
		false
	)
	if not bool(claim.get("ok", false)):
		_fail("Sunvault Starlens claim failed: %s" % JSON.stringify(claim))
		return {}
	var node: Dictionary = _resource_node_result(session, PLAYER_PLACEMENT_ID).get("node", {})
	var hero: Dictionary = session.overworld.get("hero", {})
	if String(node.get("artifact_reward_id", "")) != ARTIFACT_ID \
			or String(node.get("artifact_reward_table_id", "")) != SHRINE_TABLE_ID \
			or String(node.get("artifact_reward_claimed_by_faction_id", "")) != "player":
		_fail("Sunvault Starlens provenance is incomplete: %s" % JSON.stringify(node))
		return {}
	if ARTIFACT_ID not in ArtifactRules.owned_artifact_ids(hero) or not _artifact_equipped(hero, ARTIFACT_ID):
		_fail("Sunvault hero did not receive and equip Choir Tuning Fork: %s" % JSON.stringify(hero.get("artifacts", {})))
		return {}
	if not SpellRules.knows_spell(hero, SPELL_ID):
		_fail("Starlens artifact reward displaced the existing Beacon Path spell reward.")
		return {}
	var artifact_name := String(ContentService.get_artifact(ARTIFACT_ID).get("name", ARTIFACT_ID))
	if not String(claim.get("message", "")).contains(artifact_name):
		_fail("Starlens claim did not surface the artifact reward: %s" % String(claim.get("message", "")))
		return {}

	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	var restored = SaveService.restore_manual_session(SAVE_SLOT)
	if not bool(save_result.get("ok", false)) or restored == null:
		_fail("Starlens reward did not save and restore: %s" % JSON.stringify(save_result))
		return {}
	OverworldRules.normalize_overworld_state(restored)
	var restored_node: Dictionary = _resource_node_result(restored, PLAYER_PLACEMENT_ID).get("node", {})
	var restored_hero: Dictionary = restored.overworld.get("hero", {})
	if String(restored_node.get("artifact_reward_id", "")) != ARTIFACT_ID \
			or ARTIFACT_ID not in ArtifactRules.owned_artifact_ids(restored_hero) \
			or not _artifact_equipped(restored_hero, ARTIFACT_ID) \
			or not SpellRules.knows_spell(restored_hero, SPELL_ID):
		_fail("Starlens reward state changed across save/resume.")
		return {}

	var nodes: Array = restored.overworld.get("resource_nodes", [])
	var restored_result := _resource_node_result(restored, PLAYER_PLACEMENT_ID)
	restored_node = restored_result.get("node", {}).duplicate(true)
	restored_node["collected_by_faction_id"] = AI_FACTION_ID
	nodes[int(restored_result.get("index", -1))] = restored_node
	restored.overworld["resource_nodes"] = nodes
	var owned_before_recapture := ArtifactRules.owned_artifact_ids(restored_hero)
	var recapture := OverworldRules._collect_resource_node_result(
		restored,
		_resource_node_result(restored, PLAYER_PLACEMENT_ID),
		false
	)
	if not bool(recapture.get("ok", false)) or ArtifactRules.owned_artifact_ids(restored.overworld.get("hero", {})) != owned_before_recapture:
		_fail("Starlens recapture did not preserve one-time reward ownership: %s" % JSON.stringify(recapture))
		return {}
	return {
		"artifact_id": ARTIFACT_ID,
		"table_id": SHRINE_TABLE_ID,
		"auto_equipped": true,
		"spell_reward_preserved": true,
		"save_resume_preserved": true,
		"recapture_reward_blocked": true,
	}

func _ineligible_player_case() -> Dictionary:
	var session = _session(INELIGIBLE_SCENARIO_ID)
	_remove_known_spell(session, SPELL_ID)
	var owned_before := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	var claim := OverworldRules._collect_resource_node_result(
		session,
		_resource_node_result(session, INELIGIBLE_PLACEMENT_ID),
		false
	)
	if not bool(claim.get("ok", false)):
		_fail("Ineligible Embercourt Starlens claim failed: %s" % JSON.stringify(claim))
		return {}
	var node: Dictionary = _resource_node_result(session, INELIGIBLE_PLACEMENT_ID).get("node", {})
	var hero: Dictionary = session.overworld.get("hero", {})
	if String(node.get("artifact_reward_id", "")) != "" or ArtifactRules.owned_artifact_ids(hero) != owned_before:
		_fail("Ineligible Embercourt claim received a shrine artifact: %s" % JSON.stringify(node))
		return {}
	if not SpellRules.knows_spell(hero, SPELL_ID):
		_fail("Ineligible artifact faction gating also blocked the normal shrine spell reward.")
		return {}
	return {
		"faction_id": "faction_embercourt",
		"artifact_reward_blocked": true,
		"normal_shrine_claim_preserved": true,
		"spell_reward_preserved": true,
	}

func _ai_claim_case() -> Dictionary:
	var session = _session(AI_SCENARIO_ID)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var state := _enemy_state(session, AI_FACTION_ID)
	var roster: Array = state.get("commander_roster", []) if state.get("commander_roster", []) is Array else []
	if roster.is_empty():
		_fail("Ninefold Sunvault has no commander roster for shrine reward execution.")
		return {}
	var node: Dictionary = _resource_node_result(session, AI_PLACEMENT_ID).get("node", {})
	var raid := {
		"placement_id": "shrine_reward_ai_raid",
		"encounter_id": "encounter_glass_raid",
		"spawned_by_faction_id": AI_FACTION_ID,
		"target_kind": "resource",
		"target_placement_id": AI_PLACEMENT_ID,
		"target_x": int(node.get("x", 0)),
		"target_y": int(node.get("y", 0)),
		"goal_x": int(node.get("x", 0)),
		"goal_y": int(node.get("y", 0)),
		"x": int(node.get("x", 0)),
		"y": int(node.get("y", 0)),
		"enemy_commander_state": roster[0].get("commander_state", {}).duplicate(true),
		"target_reason_codes": ["artifact_shrine_reward_fixture"],
	}
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	var secured := EnemyAdventureRules._secure_resource_target(session, raid, state, AI_FACTION_ID)
	var reward: Dictionary = secured.get("artifact_reward", {}) if secured.get("artifact_reward", {}) is Dictionary else {}
	var secured_raid: Dictionary = secured.get("encounter", {}) if secured.get("encounter", {}) is Dictionary else {}
	var commander: Dictionary = secured_raid.get("enemy_commander_state", {}) if secured_raid.get("enemy_commander_state", {}) is Dictionary else {}
	if not bool(reward.get("applied", false)) \
			or String(reward.get("artifact_id", "")) != ARTIFACT_ID \
			or ARTIFACT_ID not in ArtifactRules.owned_artifact_ids(commander) \
			or not _artifact_equipped(commander, ARTIFACT_ID):
		_fail("Sunvault AI commander did not receive and equip the shrine artifact: %s" % JSON.stringify(secured))
		return {}
	var secured_node: Dictionary = _resource_node_result(session, AI_PLACEMENT_ID).get("node", {})
	if String(secured_node.get("artifact_reward_claimed_by_faction_id", "")) != AI_FACTION_ID \
			or String(secured_node.get("artifact_reward_id", "")) != ARTIFACT_ID:
		_fail("Sunvault AI shrine provenance was not persisted: %s" % JSON.stringify(secured_node))
		return {}
	if ARTIFACT_ID not in (secured.get("state", {}) as Dictionary).get("captured_artifact_ids", []):
		_fail("Sunvault empire state did not track the shrine artifact.")
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(secured.get("ai_events", []), 4)
	if not bool(public_log.get("ok", false)):
		_fail("AI shrine reward event crossed the public-log boundary: %s" % JSON.stringify(public_log))
		return {}
	return {
		"faction_id": AI_FACTION_ID,
		"artifact_id": ARTIFACT_ID,
		"auto_equipped": true,
		"provenance_preserved": true,
		"captured_artifact_tracked": true,
		"public_event_boundary": true,
	}

func _ai_route_claim_case() -> Dictionary:
	var session = _session(AI_SCENARIO_ID)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var state := _enemy_state(session, AI_FACTION_ID)
	var roster: Array = state.get("commander_roster", []) if state.get("commander_roster", []) is Array else []
	if roster.is_empty():
		_fail("Ninefold Sunvault has no commander roster for route shrine execution.")
		return {}
	var node_result := _resource_node_result(session, AI_PLACEMENT_ID)
	var node: Dictionary = node_result.get("node", {})
	var raid := {
		"placement_id": "shrine_reward_route_ai_raid",
		"encounter_id": "encounter_glass_raid",
		"spawned_by_faction_id": AI_FACTION_ID,
		"x": int(node.get("x", 0)),
		"y": int(node.get("y", 0)),
		"target_kind": "town",
		"target_placement_id": "riverwatch_hold",
		"enemy_commander_state": roster[0].get("commander_state", {}).duplicate(true),
		"target_reason_codes": ["artifact_shrine_route_fixture"],
	}
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	var secured := EnemyAdventureRules._secure_opportunistic_route_resource(
		session,
		{"faction_id": AI_FACTION_ID, "label": "Sunvault"},
		raid,
		state,
		AI_FACTION_ID,
		int(node_result.get("index", -1)),
		node,
		ContentService.get_resource_site(SHRINE_SITE_ID)
	)
	var reward: Dictionary = secured.get("artifact_reward", {}) if secured.get("artifact_reward", {}) is Dictionary else {}
	var secured_raid: Dictionary = secured.get("encounter", {}) if secured.get("encounter", {}) is Dictionary else {}
	var commander: Dictionary = secured_raid.get("enemy_commander_state", {}) if secured_raid.get("enemy_commander_state", {}) is Dictionary else {}
	var secured_node: Dictionary = _resource_node_result(session, AI_PLACEMENT_ID).get("node", {})
	if not bool(secured.get("resolved", false)) \
			or not bool(reward.get("applied", false)) \
			or String(reward.get("artifact_id", "")) != ARTIFACT_ID \
			or ARTIFACT_ID not in ArtifactRules.owned_artifact_ids(commander) \
			or String(secured_node.get("artifact_reward_id", "")) != ARTIFACT_ID:
		_fail("Sunvault opportunistic shrine claim did not apply the artifact reward: %s" % JSON.stringify(secured))
		return {}
	return {
		"artifact_id": ARTIFACT_ID,
		"route_claim_resolved": true,
		"commander_rewarded": true,
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

func _enemy_state(session, faction_id: String) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == faction_id:
			return state
	return {}

func _artifact_equipped(hero: Dictionary, artifact_id: String) -> bool:
	var artifacts: Dictionary = hero.get("artifacts", {}) if hero.get("artifacts", {}) is Dictionary else {}
	var equipped: Dictionary = artifacts.get("equipped", {}) if artifacts.get("equipped", {}) is Dictionary else {}
	return artifact_id in equipped.values()

func _remove_known_spell(session, spell_id: String) -> void:
	var hero: Dictionary = session.overworld.get("hero", {})
	var spellbook: Dictionary = hero.get("spellbook", {}) if hero.get("spellbook", {}) is Dictionary else {}
	var known: Array = spellbook.get("known_spell_ids", []).duplicate() if spellbook.get("known_spell_ids", []) is Array else []
	known.erase(spell_id)
	spellbook["known_spell_ids"] = known
	hero["spellbook"] = spellbook
	session.overworld["hero"] = hero

func _fail(message: String) -> void:
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
