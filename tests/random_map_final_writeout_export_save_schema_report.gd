extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "RANDOM_MAP_FINAL_WRITEOUT_EXPORT_SAVE_SCHEMA_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	var config := _config("final-writeout-export-save-schema-10184")
	var generated: Dictionary = RandomMapGeneratorRulesScript.generate(config)
	if not bool(generated.get("ok", false)):
		_fail("Generated payload failed validation: %s" % JSON.stringify(generated.get("report", {})))
		return
	var payload: Dictionary = generated.get("generated_map", {}) if generated.get("generated_map", {}) is Dictionary else {}
	if not _assert_final_export(payload):
		return

	var setup := _legacy_generated_export_setup(config, payload, generated.get("report", {}) if generated.get("report", {}) is Dictionary else {})
	if not _assert_setup_contract(setup, payload):
		return
	var scenario_id := String(setup.get("scenario_id", ""))
	if not _assert_no_authored_writeback(scenario_id, "before launch"):
		return
	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_generated_skirmish_session(
		payload,
		"normal",
		{
			"provenance": setup.get("provenance", {}),
			"replay_metadata": setup.get("replay_metadata", {}),
			"validation": setup.get("validation", {}),
			"retry_status": setup.get("retry_status", {}),
			"generated_identity": setup.get("generated_identity", {}),
			"boundary": {
				"authored_content_writeback": false,
				"campaign_adoption": false,
				"skirmish_browser_authored_listing": false,
				"alpha_parity_claim": false,
				"legacy_compatibility_only": true,
			},
		}
	)
	session.flags["generated_random_map_provenance"] = setup.get("provenance", {})
	session.flags["generated_random_map_replay_metadata"] = setup.get("replay_metadata", {})
	session.flags["generated_random_map_validation"] = setup.get("validation", {})
	session.flags["generated_random_map_retry_status"] = setup.get("retry_status", {})
	if session == null or session.scenario_id != scenario_id:
		_fail("Generated skirmish session did not launch with the expected scenario id.")
		return
	if not _assert_no_authored_writeback(scenario_id, "after launch"):
		return

	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, 4)
	if not bool(save_result.get("ok", false)):
		_fail("Generated skirmish session did not save: %s" % JSON.stringify(save_result))
		return
	var saved_payload := _load_saved_payload(String(save_result.get("path", "")))
	if not _assert_saved_contract(saved_payload, setup):
		return

	ContentService.clear_generated_scenario_drafts()
	var restore_result: Dictionary = SaveService._normalize_restore_result(saved_payload, "manual")
	if not bool(restore_result.get("ok", false)):
		_fail("Saved generated-map provenance did not restore: %s" % JSON.stringify(restore_result))
		return
	if not ContentService.has_generated_scenario_draft(scenario_id):
		_fail("Restore did not re-register the generated scenario from versioned provenance.")
		return
	if not _assert_tampered_export_rejected(saved_payload):
		return
	if not _assert_no_authored_writeback(scenario_id, "after restore"):
		return

	ContentService.clear_generated_scenario_drafts()
	var generated_export: Dictionary = payload.get("generated_export", {}) if payload.get("generated_export", {}) is Dictionary else {}
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": scenario_id,
		"generated_export_signature": generated_export.get("round_trip_signature", ""),
		"tile_stream_signature": generated_export.get("tile_stream_signature", ""),
		"object_writeout_signature": generated_export.get("object_writeout_signature", ""),
		"final_tile_stream_count": generated_export.get("final_tile_stream", []).size(),
		"object_writeout_count": generated_export.get("object_writeout_records", []).size(),
		"save_schema_status": saved_payload.get("flags", {}).get("generated_random_map_provenance", {}).get("save_schema_status", ""),
		"replay_boundary": saved_payload.get("flags", {}).get("generated_random_map_replay_metadata", {}).get("replay_boundary", ""),
	})])
	get_tree().quit(0)

func _config(seed: String) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "final_writeout_export_save_schema", "width": 26, "height": 18, "water_mode": "land", "level_count": 1},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
			"guard_strength_profile": "core_low",
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
		},
	}

func _legacy_generated_export_setup(config: Dictionary, payload: Dictionary, report: Dictionary) -> Dictionary:
	var retry_status := {
		"schema_id": "generated_random_map_retry_status_v1",
		"status": "pass",
		"attempt_count": 1,
		"max_attempts": 1,
		"retry_count": 0,
		"attempts": [],
	}
	var identity: Dictionary = ScenarioSelectRulesScript._random_map_generated_identity(payload)
	var provenance: Dictionary = ScenarioSelectRulesScript._random_map_provenance(config, payload, report, retry_status)
	return {
		"ok": true,
		"setup_kind": "generated_random_map_skirmish",
		"startup_source": "legacy_generated_export_contract_fixture",
		"launch_mode": SessionStateStoreScript.LAUNCH_MODE_SKIRMISH,
		"difficulty": "normal",
		"generated_map": payload,
		"scenario_id": String(identity.get("scenario_id", "")),
		"scenario_name": String(identity.get("scenario_id", "")),
		"template_id": String(identity.get("template_id", "")),
		"profile_id": String(identity.get("profile_id", "")),
		"normalized_seed": String(identity.get("normalized_seed", "")),
		"content_manifest_fingerprint": String(identity.get("content_manifest_fingerprint", "")),
		"generated_identity": identity,
		"validation": report,
		"retry_status": retry_status,
		"provenance": provenance,
		"replay_metadata": ScenarioSelectRulesScript._random_map_replay_metadata(provenance, identity, retry_status),
		"campaign_adoption": false,
		"alpha_parity_claim": false,
	}

func _assert_final_export(payload: Dictionary) -> bool:
	if String(payload.get("write_policy", "")) != "generated_export_record_no_authored_content_write":
		_fail("Generated payload did not use final generated export boundary.")
		return false
	var generated_export: Dictionary = payload.get("generated_export", {}) if payload.get("generated_export", {}) is Dictionary else {}
	if String(generated_export.get("schema_id", "")) != RandomMapGeneratorRulesScript.GENERATED_MAP_SERIALIZATION_SCHEMA_ID:
		_fail("Generated export schema mismatch: %s" % JSON.stringify(generated_export))
		return false
	if String(generated_export.get("export_schema_id", "")) != RandomMapGeneratorRulesScript.FINAL_WRITEOUT_EXPORT_SCHEMA_ID:
		_fail("Generated export record missed final writeout export schema.")
		return false
	var tile_stream: Array = generated_export.get("final_tile_stream", []) if generated_export.get("final_tile_stream", []) is Array else []
	var object_writeout: Array = generated_export.get("object_writeout_records", []) if generated_export.get("object_writeout_records", []) is Array else []
	if tile_stream.size() != 26 * 18 or object_writeout.is_empty():
		_fail("Generated export missed final tile stream or object writeout records.")
		return false
	var saw_road_byte := false
	for tile in tile_stream:
		if not (tile is Dictionary) or not (tile.get("tile_bytes", []) is Array) or tile.get("tile_bytes", []).size() != 7:
			_fail("Final tile stream contained invalid seven-byte tile record: %s" % JSON.stringify(tile))
			return false
		if int(tile.get("tile_bytes", [])[4]) > 0:
			saw_road_byte = true
	if not saw_road_byte:
		_fail("Final tile stream did not contain road byte writeout.")
		return false
	var completeness: Dictionary = generated_export.get("writeout_completeness", {}) if generated_export.get("writeout_completeness", {}) is Dictionary else {}
	for key in ["terrain_tile_bytes", "road_tile_bytes", "river_tile_bytes", "object_instances", "multi_tile_bodies", "round_trip_without_staging_metadata"]:
		if not bool(completeness.get(key, false)):
			_fail("Generated export missed completeness flag %s." % key)
			return false
	if bool(generated_export.get("validation_status", {}).get("staging_metadata_required_for_round_trip", true)):
		_fail("Generated export still requires staged metadata for round-trip.")
		return false
	var parsed = JSON.parse_string(JSON.stringify(generated_export))
	if not (parsed is Dictionary) or String(parsed.get("round_trip_signature", "")) != String(generated_export.get("round_trip_signature", "")):
		_fail("Generated export did not round-trip as a standalone JSON record.")
		return false
	return true

func _assert_setup_contract(setup: Dictionary, payload: Dictionary) -> bool:
	if not bool(setup.get("ok", false)):
		_fail("Random map setup failed: %s" % JSON.stringify(setup))
		return false
	var identity: Dictionary = setup.get("generated_identity", {}) if setup.get("generated_identity", {}) is Dictionary else {}
	var generated_export: Dictionary = payload.get("generated_export", {}) if payload.get("generated_export", {}) is Dictionary else {}
	if String(identity.get("generated_export_signature", "")) != String(generated_export.get("round_trip_signature", "")):
		_fail("Setup identity missed generated export signature.")
		return false
	if String(identity.get("tile_stream_signature", "")) != String(generated_export.get("tile_stream_signature", "")):
		_fail("Setup identity missed tile stream signature.")
		return false
	var provenance: Dictionary = setup.get("provenance", {}) if setup.get("provenance", {}) is Dictionary else {}
	var replay: Dictionary = setup.get("replay_metadata", {}) if setup.get("replay_metadata", {}) is Dictionary else {}
	if String(provenance.get("schema_id", "")) != "generated_random_map_skirmish_provenance_v2" or int(provenance.get("provenance_contract_version", 0)) != 2:
		_fail("Setup provenance is not versioned: %s" % JSON.stringify(provenance))
		return false
	if String(replay.get("schema_id", "")) != "generated_random_map_replay_contract_v2" or int(replay.get("replay_contract_version", 0)) != 2:
		_fail("Setup replay metadata is not versioned: %s" % JSON.stringify(replay))
		return false
	if String(replay.get("replay_boundary", "")).find("export_stream") < 0:
		_fail("Replay contract did not include generated export stream: %s" % JSON.stringify(replay))
		return false
	return true

func _assert_saved_contract(payload: Dictionary, setup: Dictionary) -> bool:
	if int(payload.get("save_version", 0)) != int(SessionStateStoreScript.SAVE_VERSION):
		_fail("Saved payload did not preserve current save version.")
		return false
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	var provenance: Dictionary = flags.get("generated_random_map_provenance", {}) if flags.get("generated_random_map_provenance", {}) is Dictionary else {}
	var replay: Dictionary = flags.get("generated_random_map_replay_metadata", {}) if flags.get("generated_random_map_replay_metadata", {}) is Dictionary else {}
	if String(provenance.get("save_schema_status", "")).find("versioned_generated_random_map_provenance_v2") < 0:
		_fail("Saved provenance missed versioned save schema status: %s" % JSON.stringify(provenance))
		return false
	if String(replay.get("replay_boundary", "")).find("export_stream") < 0:
		_fail("Saved replay metadata missed export stream boundary: %s" % JSON.stringify(replay))
		return false
	var expected_identity: Dictionary = setup.get("generated_identity", {}) if setup.get("generated_identity", {}) is Dictionary else {}
	if String(provenance.get("generated_export", {}).get("round_trip_signature", "")) != String(expected_identity.get("generated_export_signature", "")):
		_fail("Saved provenance export signature does not match setup identity.")
		return false
	if String(replay.get("generated_export", {}).get("tile_stream_signature", "")) != String(expected_identity.get("tile_stream_signature", "")):
		_fail("Saved replay tile stream signature does not match setup identity.")
		return false
	return true

func _assert_tampered_export_rejected(saved_payload: Dictionary) -> bool:
	var tampered := saved_payload.duplicate(true)
	var flags: Dictionary = tampered.get("flags", {}) if tampered.get("flags", {}) is Dictionary else {}
	var provenance: Dictionary = flags.get("generated_random_map_provenance", {}) if flags.get("generated_random_map_provenance", {}) is Dictionary else {}
	var generated_export: Dictionary = provenance.get("generated_export", {}) if provenance.get("generated_export", {}) is Dictionary else {}
	generated_export["tile_stream_signature"] = "tampered"
	provenance["generated_export"] = generated_export
	flags["generated_random_map_provenance"] = provenance
	tampered["flags"] = flags
	ContentService.clear_generated_scenario_drafts()
	var restore_result: Dictionary = SaveService._normalize_restore_result(tampered, "manual")
	if bool(restore_result.get("ok", false)):
		_fail("Tampered generated export signature restored successfully.")
		return false
	return true

func _assert_no_authored_writeback(scenario_id: String, phase: String) -> bool:
	if ContentService.has_authored_scenario(scenario_id):
		_fail("Generated scenario appeared as authored content during %s." % phase)
		return false
	for item in ContentService.load_json(ContentService.SCENARIOS_PATH).get("items", []):
		if item is Dictionary and String(item.get("id", "")) == scenario_id:
			_fail("Generated scenario was written into scenarios.json during %s." % phase)
			return false
	for campaign in ContentService.load_json(ContentService.CAMPAIGNS_PATH).get("items", []):
		if not (campaign is Dictionary):
			continue
		for entry in campaign.get("scenarios", []):
			if entry is Dictionary and String(entry.get("scenario_id", "")) == scenario_id:
				_fail("Generated scenario was written into campaign content during %s." % phase)
				return false
	return true

func _load_saved_payload(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		_fail("Save path was not written: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Could not open save path: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed.duplicate(true) if parsed is Dictionary else {}

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
