extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "RANDOM_MAP_SKIRMISH_UI_SAVE_REPLAY_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	var config := _config("skirmish-ui-save-replay-10184")
	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup(config, "normal")
	if not _assert_setup(setup):
		return

	var scenario_id := String(setup.get("scenario_id", ""))
	if not _assert_absent_from_authored_content(scenario_id, "before launch"):
		return
	if _appears_in_authored_skirmish_browser(scenario_id):
		_fail("Generated scenario appeared in authored skirmish browser before launch.")
		return

	var session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_random_map_skirmish_session(config, "normal")
	if not _assert_session(session, setup):
		return
	if not _assert_absent_from_authored_content(scenario_id, "after launch"):
		return
	if _appears_in_authored_skirmish_browser(scenario_id):
		_fail("Generated scenario appeared in authored skirmish browser after launch.")
		return

	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, 3)
	if not bool(save_result.get("ok", false)):
		_fail("Generated skirmish session did not save: %s" % JSON.stringify(save_result))
		return
	var saved_payload := _load_saved_payload(String(save_result.get("path", "")))
	if not _assert_save_replay_payload(saved_payload, setup):
		return

	ContentService.clear_generated_scenario_drafts()
	var restore_result: Dictionary = SaveService._normalize_restore_result(saved_payload, "manual")
	if not bool(restore_result.get("ok", false)):
		_fail("Saved generated-map provenance could not restore/register scenario: %s" % JSON.stringify(restore_result))
		return
	var restored_session: SessionStateStoreScript.SessionData = restore_result.get("session", null)
	if restored_session == null or restored_session.scenario_id != scenario_id:
		_fail("Restored generated-map session identity did not match saved scenario id.")
		return
	if not ContentService.has_generated_scenario_draft(scenario_id):
		_fail("Saved generated-map provenance did not re-register a transient generated scenario.")
		return
	if not _assert_absent_from_authored_content(scenario_id, "after provenance restore"):
		return

	var repeated_setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup(config, "normal")
	var changed_setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup(_config("skirmish-ui-save-replay-10184:changed"), "normal")
	if not _assert_identity_stability(setup, repeated_setup, changed_setup):
		return
	if bool(setup.get("campaign_adoption", true)) or bool(setup.get("alpha_parity_claim", true)):
		_fail("Setup exposed campaign adoption or alpha/parity claim.")
		return

	ContentService.clear_generated_scenario_drafts()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": scenario_id,
		"launch_mode": session.launch_mode,
		"template_id": setup.get("template_id", ""),
		"profile_id": setup.get("profile_id", ""),
		"normalized_seed": setup.get("normalized_seed", ""),
		"stable_signature": setup.get("generated_identity", {}).get("stable_signature", ""),
		"changed_seed_signature": changed_setup.get("generated_identity", {}).get("stable_signature", ""),
		"content_manifest_fingerprint": setup.get("content_manifest_fingerprint", ""),
		"retry_status": setup.get("retry_status", {}),
		"save_schema_status": saved_payload.get("flags", {}).get("generated_random_map_provenance", {}).get("save_schema_status", ""),
		"replay_boundary": saved_payload.get("flags", {}).get("generated_random_map_replay_metadata", {}).get("replay_boundary", ""),
	})])
	get_tree().quit(0)

func _config(seed: String) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "skirmish_ui_save_replay", "width": 26, "height": 18, "water_mode": "land", "level_count": 1},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
			"guard_strength_profile": "core_low",
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
		},
	}

func _assert_setup(setup: Dictionary) -> bool:
	if not bool(setup.get("ok", false)):
		_fail("Random-map skirmish setup failed: %s" % JSON.stringify(setup))
		return false
	if String(setup.get("launch_mode", "")) != SessionStateStoreScript.LAUNCH_MODE_SKIRMISH:
		_fail("Setup did not target skirmish launch mode: %s" % JSON.stringify(setup))
		return false
	for key in ["scenario_id", "template_id", "profile_id", "normalized_seed", "content_manifest_fingerprint"]:
		if String(setup.get(key, "")) == "":
			_fail("Setup missed required provenance key %s: %s" % [key, JSON.stringify(setup)])
			return false
	if String(setup.get("validation", {}).get("status", "")) != "pass":
		_fail("Setup did not preserve pass validation report: %s" % JSON.stringify(setup.get("validation", {})))
		return false
	var retry: Dictionary = setup.get("retry_status", {})
	if String(retry.get("status", "")) != "pass" or int(retry.get("attempt_count", 0)) != 1 or int(retry.get("retry_count", -1)) != 0:
		_fail("Setup did not preserve explicit retry status: %s" % JSON.stringify(retry))
		return false
	var provenance: Dictionary = setup.get("provenance", {})
	var replay: Dictionary = setup.get("replay_metadata", {})
	if provenance.get("generator_config", {}).is_empty() or replay.get("generator_config", {}).is_empty():
		_fail("Setup missed regeneration/replay config: %s / %s" % [JSON.stringify(provenance), JSON.stringify(replay)])
		return false
	if bool(provenance.get("campaign_adoption", true)) or bool(provenance.get("authored_content_writeback", true)) or bool(provenance.get("alpha_parity_claim", true)):
		_fail("Provenance selected a forbidden adoption/writeback/parity claim: %s" % JSON.stringify(provenance))
		return false
	return true

func _assert_session(session: SessionStateStoreScript.SessionData, setup: Dictionary) -> bool:
	if session == null or session.scenario_id == "":
		_fail("Random-map skirmish session did not launch.")
		return false
	if session.launch_mode != SessionStateStoreScript.LAUNCH_MODE_SKIRMISH:
		_fail("Generated map launched outside skirmish boundary: %s" % session.launch_mode)
		return false
	if session.scenario_id != String(setup.get("scenario_id", "")):
		_fail("Session scenario id did not match setup identity.")
		return false
	if not bool(session.flags.get("generated_random_map", false)):
		_fail("Session did not carry generated random-map flag.")
		return false
	for key in ["generated_random_map_provenance", "generated_random_map_replay_metadata", "generated_random_map_validation", "generated_random_map_retry_status"]:
		if not (session.flags.get(key, {}) is Dictionary) or session.flags.get(key, {}).is_empty():
			_fail("Session flags missed %s." % key)
			return false
	var boundary: Dictionary = session.flags.get("generated_random_map_boundary", {})
	if String(boundary.get("adoption_path", "")) != "skirmish_session_only_no_authored_browser_or_campaign":
		_fail("Session boundary did not preserve skirmish-only adoption path: %s" % JSON.stringify(boundary))
		return false
	if session.flags.has("campaign_id") or session.flags.has("campaign_name") or session.flags.has("campaign_chapter_label"):
		_fail("Generated skirmish session picked up campaign flags: %s" % JSON.stringify(session.flags))
		return false
	if session.overworld.get("generated_random_map_provenance", {}).is_empty():
		_fail("Session overworld missed generated-map provenance.")
		return false
	return true

func _assert_save_replay_payload(payload: Dictionary, setup: Dictionary) -> bool:
	if payload.is_empty():
		_fail("Saved payload was empty.")
		return false
	if String(payload.get("launch_mode", "")) != SessionStateStoreScript.LAUNCH_MODE_SKIRMISH:
		_fail("Saved payload did not preserve skirmish launch mode.")
		return false
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	var provenance: Dictionary = flags.get("generated_random_map_provenance", {}) if flags.get("generated_random_map_provenance", {}) is Dictionary else {}
	var replay: Dictionary = flags.get("generated_random_map_replay_metadata", {}) if flags.get("generated_random_map_replay_metadata", {}) is Dictionary else {}
	var retry: Dictionary = flags.get("generated_random_map_retry_status", {}) if flags.get("generated_random_map_retry_status", {}) is Dictionary else {}
	for key in ["normalized_seed", "generator_version", "template_id", "profile_id", "content_manifest_fingerprint"]:
		if String(provenance.get(key, "")) == "":
			_fail("Saved provenance missed %s: %s" % [key, JSON.stringify(provenance)])
			return false
	if String(provenance.get("normalized_seed", "")) != String(setup.get("normalized_seed", "")):
		_fail("Saved provenance seed changed.")
		return false
	if String(provenance.get("save_schema_status", "")).find("without_save_version_bump") < 0:
		_fail("Save provenance did not expose staged/deferred schema status: %s" % JSON.stringify(provenance))
		return false
	if replay.get("generator_config", {}).is_empty() or String(replay.get("replay_boundary", "")).find("seed_config_identity") < 0 or String(replay.get("replay_boundary", "")).find("export_stream") < 0:
		_fail("Replay metadata missed seed/config export-stream boundary: %s" % JSON.stringify(replay))
		return false
	if String(provenance.get("schema_id", "")) != "generated_random_map_skirmish_provenance_v2" or int(provenance.get("provenance_contract_version", 0)) < 2:
		_fail("Saved provenance missed versioned schema contract: %s" % JSON.stringify(provenance))
		return false
	if provenance.get("generated_export", {}).is_empty() or replay.get("generated_export", {}).is_empty():
		_fail("Saved provenance/replay missed generated export signatures: %s / %s" % [JSON.stringify(provenance), JSON.stringify(replay)])
		return false
	if String(retry.get("status", "")) != "pass" or int(retry.get("retry_count", -1)) != 0:
		_fail("Saved retry status missing or invalid: %s" % JSON.stringify(retry))
		return false
	if flags.has("campaign_id") or flags.has("campaign_name") or flags.has("campaign_chapter_label"):
		_fail("Saved generated-map session included campaign flags.")
		return false
	return true

func _assert_identity_stability(first_setup: Dictionary, repeated_setup: Dictionary, changed_setup: Dictionary) -> bool:
	if not bool(repeated_setup.get("ok", false)) or not bool(changed_setup.get("ok", false)):
		_fail("Repeated or changed-seed setup failed: repeated=%s changed=%s." % [JSON.stringify(repeated_setup), JSON.stringify(changed_setup)])
		return false
	var first_identity: Dictionary = first_setup.get("generated_identity", {})
	var repeated_identity: Dictionary = repeated_setup.get("generated_identity", {})
	var changed_identity: Dictionary = changed_setup.get("generated_identity", {})
	if String(first_identity.get("scenario_id", "")) != String(repeated_identity.get("scenario_id", "")):
		_fail("Same seed/config changed generated scenario id.")
		return false
	if String(first_identity.get("stable_signature", "")) != String(repeated_identity.get("stable_signature", "")):
		_fail("Same seed/config changed stable generated identity.")
		return false
	if String(first_identity.get("scenario_id", "")) == String(changed_identity.get("scenario_id", "")):
		_fail("Changed seed did not change generated scenario id.")
		return false
	if String(first_identity.get("stable_signature", "")) == String(changed_identity.get("stable_signature", "")):
		_fail("Changed seed did not change stable generated identity.")
		return false
	return true

func _assert_absent_from_authored_content(scenario_id: String, phase: String) -> bool:
	if scenario_id == "":
		_fail("Generated scenario id was empty during %s." % phase)
		return false
	if ContentService.has_authored_scenario(scenario_id):
		_fail("Generated scenario id %s appeared in authored scenarios during %s." % [scenario_id, phase])
		return false
	for item in ContentService.load_json(ContentService.SCENARIOS_PATH).get("items", []):
		if item is Dictionary and String(item.get("id", "")) == scenario_id:
			_fail("Generated scenario id %s was written into scenarios.json during %s." % [scenario_id, phase])
			return false
	for campaign in ContentService.load_json(ContentService.CAMPAIGNS_PATH).get("items", []):
		if not (campaign is Dictionary):
			continue
		for campaign_scenario in campaign.get("scenarios", []):
			if campaign_scenario is Dictionary and String(campaign_scenario.get("scenario_id", "")) == scenario_id:
				_fail("Generated scenario id %s appeared in campaign content during %s." % [scenario_id, phase])
				return false
	return true

func _appears_in_authored_skirmish_browser(scenario_id: String) -> bool:
	for entry in ScenarioSelectRulesScript.build_skirmish_browser_entries():
		if entry is Dictionary and String(entry.get("scenario_id", "")) == scenario_id:
			return true
	return false

func _load_saved_payload(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		_fail("Save path was not written: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Could not open save path: %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		_fail("Saved payload JSON did not parse.")
		return {}
	return parser.data.duplicate(true) if parser.data is Dictionary else {}

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
