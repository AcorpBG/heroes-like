extends Node

const REPORT_ID := "ARTIFACT_BATTLE_SALVAGE_EXECUTION_REPORT"
const SCENARIO_ID := "bellwake-wreck-claim"
const SALVAGE_PLACEMENT_ID := "bellwake_aurora_battery"
const CONTROL_PLACEMENT_ID := "bellwake_relay_pickets"
const EXPECTED_ARTIFACT_ID := "artifact_warcrest_pennon"
const RESERVED_ARTIFACT_ID := "artifact_black_sail_compass"
const SAVE_SLOT := 4

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var control := _control_encounter_case()
	if control.is_empty():
		return
	var session = _session()
	var source_context: Dictionary = _encounter(session, SALVAGE_PLACEMENT_ID).get("artifact_source_context", {})
	var faction_rejection := ArtifactRules.select_live_source_reward(
		"battle_salvage",
		source_context,
		"%s:%s:faction_rejection" % [SCENARIO_ID, SALVAGE_PLACEMENT_ID],
		"faction_embercourt"
	)
	if String(faction_rejection.get("reason", "")) != "faction_ineligible":
		_fail("Battle-salvage table accepted a non-Veilmourn faction: %s" % JSON.stringify(faction_rejection))
		return

	var outcome := _win_encounter(session, SALVAGE_PLACEMENT_ID)
	if String(outcome.get("state", "")) != "victory":
		_fail("Aurora Battery did not resolve through the live victory path: %s" % JSON.stringify(outcome))
		return
	var owned := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	if EXPECTED_ARTIFACT_ID not in owned or RESERVED_ARTIFACT_ID in owned:
		_fail("Battle salvage did not reserve the map artifact and select the deterministic reward: %s" % JSON.stringify(owned))
		return
	var location := ArtifactRules.locate_artifact(session.overworld.get("hero", {}), EXPECTED_ARTIFACT_ID)
	if String(location.get("location", "")) != "equipped" or String(location.get("slot", "")) != "banner":
		_fail("Battle-salvage reward was not auto-equipped: %s" % JSON.stringify(location))
		return
	var aftermath: Dictionary = session.flags.get("last_battle_aftermath", {})
	if not String(aftermath.get("artifact_summary", "")).contains("Warcrest Pennon"):
		_fail("Battle aftermath omitted the salvage artifact: %s" % JSON.stringify(aftermath))
		return
	var source_key := "%s:%s:battle_salvage" % [SCENARIO_ID, SALVAGE_PLACEMENT_ID]
	var claims: Dictionary = session.flags.get("artifact_source_claims", {})
	var provenance: Dictionary = claims.get(source_key, {})
	if (
		String(provenance.get("artifact_id", "")) != EXPECTED_ARTIFACT_ID
		or String(provenance.get("table_id", "")) != "artifact_source_battle_salvage_heavy"
		or String(provenance.get("claimed_by_faction_id", "")) != "faction_veilmourn"
	):
		_fail("Battle-salvage provenance was incomplete: %s" % JSON.stringify(provenance))
		return

	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	var restored = SaveService.restore_manual_session(SAVE_SLOT)
	if not bool(save_result.get("ok", false)) or restored == null:
		_fail("Battle-salvage state did not save and restore: %s" % JSON.stringify(save_result))
		return
	OverworldRules.normalize_overworld_state(restored)
	var restored_claims: Dictionary = restored.flags.get("artifact_source_claims", {})
	if (
		EXPECTED_ARTIFACT_ID not in ArtifactRules.owned_artifact_ids(restored.overworld.get("hero", {}))
		or String(restored_claims.get(source_key, {}).get("artifact_id", "")) != EXPECTED_ARTIFACT_ID
		or not String(restored.flags.get("last_battle_aftermath", {}).get("artifact_summary", "")).contains("Warcrest Pennon")
	):
		_fail("Restored battle-salvage state lost artifact, provenance, or aftermath.")
		return
	var count_before_duplicate := ArtifactRules.owned_artifact_ids(restored.overworld.get("hero", {})).size()
	var duplicate_outcome := _win_encounter(restored, SALVAGE_PLACEMENT_ID)
	var restored_owned := ArtifactRules.owned_artifact_ids(restored.overworld.get("hero", {}))
	if String(duplicate_outcome.get("state", "")) != "victory" or restored_owned.size() != count_before_duplicate:
		_fail("Repeated Aurora Battery resolution granted another artifact: %s / %s" % [JSON.stringify(duplicate_outcome), JSON.stringify(restored_owned)])
		return
	var duplicate_claims: Dictionary = restored.flags.get("artifact_source_claims", {})
	if duplicate_claims.size() != restored_claims.size() or String(duplicate_claims.get(source_key, {}).get("artifact_id", "")) != EXPECTED_ARTIFACT_ID:
		_fail("Repeated Aurora Battery resolution changed source provenance: %s" % JSON.stringify(duplicate_claims))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"control_encounter": control,
		"salvage_placement_id": SALVAGE_PLACEMENT_ID,
		"artifact_id": EXPECTED_ARTIFACT_ID,
		"reserved_map_artifact_id": RESERVED_ARTIFACT_ID,
		"auto_equipped_slot": String(location.get("slot", "")),
		"aftermath_visible": true,
		"provenance": provenance,
		"save_resume_preserved": true,
		"duplicate_reward_blocked": true,
		"faction_rejection": String(faction_rejection.get("reason", "")),
		"save_version": SessionStateStore.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _control_encounter_case() -> Dictionary:
	var session = _session()
	var owned_before := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	var outcome := _win_encounter(session, CONTROL_PLACEMENT_ID)
	var owned_after := ArtifactRules.owned_artifact_ids(session.overworld.get("hero", {}))
	if String(outcome.get("state", "")) != "victory" or owned_after != owned_before or session.flags.has("artifact_source_claims"):
		_fail("Non-opted-in Relay Pickets granted battle salvage: %s / %s" % [JSON.stringify(outcome), JSON.stringify(owned_after)])
		return {}
	return {"placement_id": CONTROL_PLACEMENT_ID, "reward_blocked": true}

func _win_encounter(session, placement_id: String) -> Dictionary:
	var encounter := _encounter(session, placement_id)
	if encounter.is_empty():
		return {"state": "invalid", "message": "Missing encounter %s." % placement_id}
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		return {"state": "invalid", "message": "Battle payload was empty for %s." % placement_id}
	var stacks: Array = session.battle.get("stacks", [])
	var has_player := false
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary):
			continue
		if String(stack.get("side", "")) == "enemy":
			stack["total_health"] = 0
		elif String(stack.get("side", "")) == "player":
			has_player = true
			stack["total_health"] = max(1, int(stack.get("total_health", 1)))
		stacks[index] = stack
	if not has_player:
		return {"state": "invalid", "message": "Battle payload had no player stack."}
	session.battle["stacks"] = stacks
	return BattleRules.resolve_if_battle_ready(session)

func _session():
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	return session

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _fail(message: String) -> void:
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
