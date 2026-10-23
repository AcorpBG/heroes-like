extends Node
## A generated game's save schema: a new game from a native generated map
## package saves with its versioned provenance, replay metadata and package
## refs, loads back with them, and a restore that finds no generated scenario
## registers the package-backed scenario again. Nothing reaches the authored
## content.
##
## Run with an isolated user profile: it writes manual slot 4.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "RANDOM_MAP_FINAL_WRITEOUT_EXPORT_SAVE_SCHEMA_REPORT"
const PROVENANCE_SCHEMA_ID := "aurelion_native_rmg_disk_package_provenance_v1"
const REPLAY_SCHEMA_ID := "generated_random_map_replay_contract_v2"
const SAVE_SLOT := 4

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	var config := ScenarioSelectRulesScript.build_random_map_player_config("10184", "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO, "faction_embercourt", "")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	if not _assert_setup(setup):
		return
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		_fail("The generated game did not start.")
		return
	var scenario_id: String = session.scenario_id
	if not _assert_no_authored_writeback(scenario_id, "after launch"):
		return

	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	if not bool(save_result.get("ok", false)):
		_fail("The generated game did not save: %s" % JSON.stringify(save_result))
		return
	var saved_payload := _load_saved_payload(String(save_result.get("path", "")))
	if not _assert_saved_contract(saved_payload, setup):
		return

	ContentService.clear_generated_scenario_drafts()
	var restore_result: Dictionary = SaveService._normalize_restore_result(saved_payload, "manual")
	if not bool(restore_result.get("ok", false)):
		_fail("The saved generated game did not restore: %s" % JSON.stringify(restore_result.get("message", restore_result)))
		return
	if not ContentService.has_generated_scenario_draft(scenario_id):
		_fail("The restore did not register the package-backed scenario again.")
		return
	var restored = restore_result.get("session", null)
	if restored == null or restored.scenario_id != scenario_id:
		_fail("The restored session is not the saved game.")
		return
	var restored_provenance: Dictionary = restored.flags.get("generated_random_map_provenance", {})
	if JSON.stringify(restored_provenance.get("map_ref", {})) != JSON.stringify(setup.get("provenance", {}).get("map_ref", {})):
		_fail("The restored game lost its map package ref.")
		return
	if not _assert_no_authored_writeback(scenario_id, "after restore"):
		return

	ContentService.clear_generated_scenario_drafts()
	var provenance: Dictionary = saved_payload.get("flags", {}).get("generated_random_map_provenance", {})
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": scenario_id,
		"map_hash": String(provenance.get("map_ref", {}).get("map_hash", "")),
		"scenario_hash": String(provenance.get("scenario_ref", {}).get("scenario_hash", "")),
		"save_version": int(saved_payload.get("save_version", 0)),
	})])
	get_tree().quit(0)

func _assert_setup(setup: Dictionary) -> bool:
	if not bool(setup.get("ok", false)):
		_fail("The generated setup failed: %s" % String(setup.get("failure_handoff", JSON.stringify(setup.get("validation", {})))))
		return false
	var package_startup: Dictionary = setup.get("package_startup", {}) if setup.get("package_startup", {}) is Dictionary else {}
	for key in ["map_path", "scenario_path"]:
		if not FileAccess.file_exists(String(package_startup.get(key, ""))):
			_fail("The setup did not write its %s package." % key.trim_suffix("_path"))
			return false
	var provenance: Dictionary = setup.get("provenance", {}) if setup.get("provenance", {}) is Dictionary else {}
	if String(provenance.get("schema_id", "")) != PROVENANCE_SCHEMA_ID:
		_fail("The setup provenance is not the package provenance: %s" % String(provenance.get("schema_id", "")))
		return false
	if String(provenance.get("map_ref", {}).get("map_hash", "")) == "" or String(provenance.get("scenario_ref", {}).get("scenario_hash", "")) == "":
		_fail("The setup provenance has no package hashes.")
		return false
	var replay: Dictionary = setup.get("replay_metadata", {}) if setup.get("replay_metadata", {}) is Dictionary else {}
	if String(replay.get("schema_id", "")) != REPLAY_SCHEMA_ID or int(replay.get("replay_contract_version", 0)) != 2:
		_fail("The setup replay metadata is not versioned: %s" % String(replay.get("schema_id", "")))
		return false
	return true

func _assert_saved_contract(payload: Dictionary, setup: Dictionary) -> bool:
	if int(payload.get("save_version", 0)) != int(SessionStateStoreScript.SAVE_VERSION):
		_fail("The save does not have the current save version.")
		return false
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	var provenance: Dictionary = flags.get("generated_random_map_provenance", {}) if flags.get("generated_random_map_provenance", {}) is Dictionary else {}
	var replay: Dictionary = flags.get("generated_random_map_replay_metadata", {}) if flags.get("generated_random_map_replay_metadata", {}) is Dictionary else {}
	if String(provenance.get("schema_id", "")) != PROVENANCE_SCHEMA_ID:
		_fail("The save lost the package provenance.")
		return false
	if String(replay.get("schema_id", "")) != REPLAY_SCHEMA_ID:
		_fail("The save lost the replay metadata.")
		return false
	var expected: Dictionary = setup.get("provenance", {})
	for key in ["map_ref", "scenario_ref", "normalized_config"]:
		if _saved_json(provenance.get(key, {})) != _saved_json(expected.get(key, {})):
			_fail("The saved provenance %s is not the setup's." % key)
			return false
	var overworld: Dictionary = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	if _saved_json(overworld.get("map_package_ref", {})) != _saved_json(expected.get("map_ref", {})):
		_fail("The saved overworld lost its map package ref.")
		return false
	return true

## A value as the save file holds it: JSON reads every number back as a float.
func _saved_json(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))

func _assert_no_authored_writeback(scenario_id: String, phase: String) -> bool:
	if ContentService.has_authored_scenario(scenario_id):
		_fail("The generated scenario appeared as authored content %s." % phase)
		return false
	return true

func _load_saved_payload(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		_fail("The save was not written: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("The save could not be opened: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed.duplicate(true) if parsed is Dictionary else {}

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
