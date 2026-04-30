extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "RANDOM_MAP_PLAYABLE_MATERIALIZATION_RUNTIME_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	var config := _config("skirmish-ui-save-replay-10184", "translated_rmg_profile_043_v1")
	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup(config, "normal")
	if not _assert_setup_materialization(setup):
		return
	var scenario_id := String(setup.get("scenario_id", ""))
	if not _assert_no_authored_writeback(scenario_id, "before launch"):
		return

	var session: SessionStateStoreScript.SessionData = ScenarioSelectRulesScript.start_random_map_skirmish_session(config, "normal")
	if not _assert_runtime_session(session, setup):
		return
	if not _assert_materialized_overworld(session):
		return
	if not _assert_bounded_overworld_interaction(session):
		return
	if not _assert_no_authored_writeback(scenario_id, "after launch and move"):
		return

	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, 2)
	if not bool(save_result.get("ok", false)):
		_fail("Runtime materialized generated map did not save: %s" % JSON.stringify(save_result))
		return
	var saved_payload := _load_saved_payload(String(save_result.get("path", "")))
	if not _assert_saved_materialization(saved_payload, setup):
		return

	ContentService.clear_generated_scenario_drafts()
	var restore_result: Dictionary = SaveService._normalize_restore_result(saved_payload, "manual")
	if not bool(restore_result.get("ok", false)):
		_fail("Runtime materialized generated-map save did not restore: %s" % JSON.stringify(restore_result))
		return
	var restored_session: SessionStateStoreScript.SessionData = restore_result.get("session", null)
	if not _assert_restored_materialization(restored_session, setup):
		return
	if not _assert_no_authored_writeback(scenario_id, "after restore"):
		return

	var repeated_setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup(config, "normal")
	var changed_seed_setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup(_config("skirmish-ui-save-replay-10184:changed", "translated_rmg_profile_043_v1"), "normal")
	var changed_profile_setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup(_config("skirmish-ui-save-replay-10184", "translated_rmg_profile_042_v1"), "normal")
	if not _assert_materialization_determinism(setup, repeated_setup, changed_seed_setup, changed_profile_setup):
		return
	var accepted_player_counts := _assert_extra_large_player_count_generation([5, 6, 7, 8])
	if accepted_player_counts.is_empty():
		return

	ContentService.clear_generated_scenario_drafts()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": scenario_id,
		"launch_mode": session.launch_mode,
		"stable_signature": setup.get("generated_identity", {}).get("stable_signature", ""),
		"materialized_map_signature": setup.get("generated_identity", {}).get("materialized_map_signature", ""),
		"changed_seed_materialized_map_signature": changed_seed_setup.get("generated_identity", {}).get("materialized_map_signature", ""),
			"changed_profile_materialized_map_signature": changed_profile_setup.get("generated_identity", {}).get("materialized_map_signature", ""),
			"runtime_summary": session.overworld.get(SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG, {}).get("summary", {}),
			"materialized_size": setup.get("generated_identity", {}).get("materialized_size", {}),
			"accepted_xl_player_counts": accepted_player_counts,
			"topology": _topology_summary(setup),
			"counts": _materialized_counts(setup),
			"save_replay_boundary": saved_payload.get("flags", {}).get("generated_random_map_replay_metadata", {}).get("replay_boundary", ""),
		})])
	get_tree().quit(0)

func _config(seed: String, profile_id: String, player_count: int = 4) -> Dictionary:
	var template_id := "translated_rmg_template_042_v1" if profile_id == "translated_rmg_profile_042_v1" else "translated_rmg_template_043_v1"
	return ScenarioSelectRulesScript.build_random_map_player_config(
		seed,
		template_id,
		profile_id,
		player_count,
		"land",
		false,
		"homm3_extra_large"
	)

func _assert_setup_materialization(setup: Dictionary) -> bool:
	if not bool(setup.get("ok", false)):
		_fail("Generated setup failed validation: %s" % JSON.stringify(setup))
		return false
	var generated_map: Dictionary = setup.get("generated_map", {}) if setup.get("generated_map", {}) is Dictionary else {}
	var materialization: Dictionary = generated_map.get("runtime_materialization", {}) if generated_map.get("runtime_materialization", {}) is Dictionary else {}
	if String(materialization.get("schema_id", "")) != RandomMapGeneratorRulesScript.PLAYABLE_RUNTIME_MATERIALIZATION_SCHEMA_ID:
		_fail("Runtime materialization schema missing: %s" % JSON.stringify(materialization))
		return false
	if String(materialization.get("materialized_map_signature", "")) == "":
		_fail("Runtime materialization signature missing.")
		return false
	var identity: Dictionary = setup.get("generated_identity", {}) if setup.get("generated_identity", {}) is Dictionary else {}
	if String(identity.get("materialized_map_signature", "")) != String(materialization.get("materialized_map_signature", "")):
		_fail("Setup identity did not expose materialized-map signature.")
		return false
	if not _assert_honest_extra_large_dimensions(setup, materialization):
		return false
	if not _assert_extra_large_topology(setup):
		return false
	return _assert_materialized_categories(materialization)

func _assert_runtime_session(session: SessionStateStoreScript.SessionData, setup: Dictionary) -> bool:
	if session == null or session.scenario_id == "":
		_fail("Generated map did not launch a runtime session.")
		return false
	if session.launch_mode != SessionStateStoreScript.LAUNCH_MODE_SKIRMISH:
		_fail("Generated map launched outside the explicit skirmish runtime boundary.")
		return false
	if session.scenario_id != String(setup.get("scenario_id", "")):
		_fail("Runtime session scenario id changed during launch.")
		return false
	if not ContentService.has_generated_scenario_draft(session.scenario_id):
		_fail("Runtime launch did not register the generated scenario in the transient registry.")
		return false
	return true

func _assert_materialized_overworld(session: SessionStateStoreScript.SessionData) -> bool:
	OverworldRulesScript.normalize_overworld_state(session)
	var materialization: Dictionary = session.overworld.get(SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY, {}) if session.overworld.get(SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY, {}) is Dictionary else {}
	if materialization.is_empty():
		_fail("Overworld state missed the concrete runtime materialization payload.")
		return false
	if String(materialization.get("materialized_map_signature", "")) != String(session.flags.get(SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG, {}).get("materialized_map_signature", "")):
		_fail("Overworld and flags disagreed on materialized-map signature.")
		return false
	if session.overworld.get("map", []).is_empty() or session.overworld.get("terrain_layers", {}).is_empty():
		_fail("Overworld did not consume generated terrain/map structures.")
		return false
	if session.overworld.get("towns", []).is_empty() or session.overworld.get("resource_nodes", []).is_empty() or session.overworld.get("encounters", []).is_empty():
		_fail("Overworld missed generated towns, resources, or guards.")
		return false
	if not _assert_honest_extra_large_dimensions({}, materialization):
		return false
	return _assert_materialized_categories(materialization)

func _assert_bounded_overworld_interaction(session: SessionStateStoreScript.SessionData) -> bool:
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for direction in directions:
		var pos := OverworldRulesScript.hero_position(session)
		var nx := int(pos.x + direction.x)
		var ny := int(pos.y + direction.y)
		if OverworldRulesScript.tile_is_blocked(session, nx, ny):
			continue
		var result: Dictionary = OverworldRulesScript.try_move(session, direction.x, direction.y)
		if bool(result.get("ok", false)):
			return true
	_fail("No bounded generated-map overworld movement path succeeded.")
	return false

func _assert_saved_materialization(payload: Dictionary, setup: Dictionary) -> bool:
	if payload.is_empty():
		_fail("Saved payload was empty.")
		return false
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	var identity: Dictionary = setup.get("generated_identity", {}) if setup.get("generated_identity", {}) is Dictionary else {}
	var saved_materialization: Dictionary = flags.get(SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG, {}) if flags.get(SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG, {}) is Dictionary else {}
	var provenance: Dictionary = flags.get("generated_random_map_provenance", {}) if flags.get("generated_random_map_provenance", {}) is Dictionary else {}
	var replay: Dictionary = flags.get("generated_random_map_replay_metadata", {}) if flags.get("generated_random_map_replay_metadata", {}) is Dictionary else {}
	if String(saved_materialization.get("materialized_map_signature", "")) != String(identity.get("materialized_map_signature", "")):
		_fail("Saved flags did not preserve materialized-map signature.")
		return false
	if String(provenance.get("generated_identity", {}).get("materialized_map_signature", "")) != String(identity.get("materialized_map_signature", "")):
		_fail("Saved provenance missed materialized-map identity.")
		return false
	if String(replay.get("generated_identity", {}).get("materialized_map_signature", "")) != String(identity.get("materialized_map_signature", "")):
		_fail("Replay metadata missed materialized-map identity.")
		return false
	if payload.get("overworld", {}).get(SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY, {}).is_empty():
		_fail("Saved overworld missed concrete runtime materialization payload.")
		return false
	var saved_overworld_materialization: Dictionary = payload.get("overworld", {}).get(SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY, {}) if payload.get("overworld", {}).get(SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY, {}) is Dictionary else {}
	if not _assert_honest_extra_large_dimensions(setup, saved_overworld_materialization):
		return false
	return true

func _assert_restored_materialization(session: SessionStateStoreScript.SessionData, setup: Dictionary) -> bool:
	if session == null:
		_fail("Restore returned no session.")
		return false
	var restored_identity: Dictionary = session.flags.get(SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG, {}) if session.flags.get(SessionStateStoreScript.GENERATED_RANDOM_MAP_MATERIALIZATION_FLAG, {}) is Dictionary else {}
	if String(restored_identity.get("materialized_map_signature", "")) != String(setup.get("generated_identity", {}).get("materialized_map_signature", "")):
		_fail("Restored session lost materialized-map signature.")
		return false
	if session.overworld.get(SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY, {}).is_empty():
		_fail("Restored session missed generated runtime materialization payload.")
		return false
	if not ContentService.has_generated_scenario_draft(session.scenario_id):
		_fail("Restore did not re-register generated scenario from provenance.")
		return false
	var materialization: Dictionary = session.overworld.get(SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY, {}) if session.overworld.get(SessionStateStoreScript.GENERATED_MAP_RUNTIME_MATERIALIZATION_KEY, {}) is Dictionary else {}
	if not _assert_honest_extra_large_dimensions(setup, materialization):
		return false
	return true

func _assert_materialization_determinism(first: Dictionary, repeated: Dictionary, changed_seed: Dictionary, changed_profile: Dictionary) -> bool:
	for setup in [repeated, changed_seed, changed_profile]:
		if not bool(setup.get("ok", false)):
			_fail("Determinism comparison setup failed: %s" % JSON.stringify(setup))
			return false
	var first_sig := String(first.get("generated_identity", {}).get("materialized_map_signature", ""))
	if first_sig == "" or first_sig != String(repeated.get("generated_identity", {}).get("materialized_map_signature", "")):
		_fail("Same input did not reproduce the materialized-map signature.")
		return false
	if first_sig == String(changed_seed.get("generated_identity", {}).get("materialized_map_signature", "")):
		_fail("Changed seed did not change the materialized-map signature.")
		return false
	if first_sig == String(changed_profile.get("generated_identity", {}).get("materialized_map_signature", "")):
		_fail("Changed profile id did not change the materialized-map signature.")
		return false
	return true

func _assert_extra_large_player_count_generation(player_counts: Array) -> Array:
	var accepted := []
	for player_count in player_counts:
		var normalized := RandomMapGeneratorRulesScript.normalize_config(
			_config("xl-player-count-%d-10184" % int(player_count), "translated_rmg_profile_043_v1", int(player_count))
		)
		var selection: Dictionary = normalized.get("template_selection", {}) if normalized.get("template_selection", {}) is Dictionary else {}
		if bool(selection.get("rejected", true)):
			_fail("XL translated template rejected valid player_count=%d during generator selection: %s" % [int(player_count), JSON.stringify(selection)])
			return []
		var constraints: Dictionary = normalized.get("player_constraints", {}) if normalized.get("player_constraints", {}) is Dictionary else {}
		var assignment: Dictionary = normalized.get("player_assignment", {}) if normalized.get("player_assignment", {}) is Dictionary else {}
		if int(constraints.get("player_count", 0)) != int(player_count):
			_fail("XL translated template normalized player_count=%d to %s." % [int(player_count), JSON.stringify(constraints)])
			return []
		if assignment.get("player_slots", []).size() != int(player_count):
			_fail("XL translated template did not assign %d player slots: %s" % [int(player_count), JSON.stringify(assignment)])
			return []
		accepted.append(int(player_count))
	return accepted

func _assert_honest_extra_large_dimensions(setup: Dictionary, materialization: Dictionary) -> bool:
	var map_size: Dictionary = materialization.get("map_size", {}) if materialization.get("map_size", {}) is Dictionary else {}
	if int(map_size.get("width", 0)) != 144 or int(map_size.get("height", 0)) != 144:
		_fail("Runtime materialization did not preserve Extra Large 144x144 map size: %s" % JSON.stringify(map_size))
		return false
	var rows: Array = materialization.get("terrain", {}).get("rows", []) if materialization.get("terrain", {}).get("rows", []) is Array else []
	if rows.size() != 144:
		_fail("Runtime materialization terrain row count was not 144: %d" % rows.size())
		return false
	if not rows.is_empty() and (not (rows[0] is Array) or rows[0].size() != 144):
		_fail("Runtime materialization terrain column count was not 144.")
		return false
	if not setup.is_empty():
		var identity: Dictionary = setup.get("generated_identity", {}) if setup.get("generated_identity", {}) is Dictionary else {}
		var source_size: Dictionary = identity.get("source_size", {}) if identity.get("source_size", {}) is Dictionary else {}
		var materialized_size: Dictionary = identity.get("materialized_size", {}) if identity.get("materialized_size", {}) is Dictionary else {}
		if String(identity.get("size_class_id", "")) != "homm3_extra_large" or int(source_size.get("width", 0)) != 144 or int(source_size.get("height", 0)) != 144:
			_fail("Generated identity missed Extra Large source provenance: %s" % JSON.stringify(identity))
			return false
		if int(materialized_size.get("width", 0)) != 144 or int(materialized_size.get("height", 0)) != 144:
			_fail("Generated identity materialized dimensions did not equal source dimensions: %s" % JSON.stringify(identity))
			return false
	return true

func _assert_materialized_categories(materialization: Dictionary) -> bool:
	var objects: Dictionary = materialization.get("objects", {}) if materialization.get("objects", {}) is Dictionary else {}
	var starts: Dictionary = materialization.get("starts", {}) if materialization.get("starts", {}) is Dictionary else {}
	var constraints: Dictionary = materialization.get("generated_constraints", {}) if materialization.get("generated_constraints", {}) is Dictionary else {}
	var required_arrays := {
		"towns": objects.get("towns", []),
		"resources": objects.get("resources", []),
		"mines": objects.get("mines", []),
		"dwellings": objects.get("dwellings", []),
		"guards": objects.get("guards", []),
		"rewards": objects.get("rewards", []),
		"object_instances": objects.get("object_instances", []),
		"hero_starts": starts.get("hero_starts", []),
	}
	for key in required_arrays.keys():
		var value = required_arrays[key]
		if not (value is Array) or value.is_empty():
			_fail("Runtime materialization missed %s." % key)
			return false
	for key in ["zone_layout", "terrain_transit", "connection_guard_materialization", "monster_reward_bands", "town_mine_dwelling_placement", "roads_rivers_writeout", "fairness"]:
		if not (constraints.get(key, {}) is Dictionary) or constraints.get(key, {}).is_empty():
			_fail("Runtime materialization missed generated constraint %s." % key)
			return false
	if bool(materialization.get("boundary", {}).get("authored_content_writeback", true)) or bool(materialization.get("boundary", {}).get("campaign_record", true)) or bool(materialization.get("boundary", {}).get("parity_or_alpha_claim", true)):
		_fail("Runtime materialization violated generated-map boundary: %s" % JSON.stringify(materialization.get("boundary", {})))
		return false
	return true

func _assert_extra_large_topology(setup: Dictionary) -> bool:
	var generated_map: Dictionary = setup.get("generated_map", {}) if setup.get("generated_map", {}) is Dictionary else {}
	var metadata: Dictionary = generated_map.get("metadata", {}) if generated_map.get("metadata", {}) is Dictionary else {}
	var phases: Array = generated_map.get("phase_pipeline", []) if generated_map.get("phase_pipeline", []) is Array else []
	var topology := _topology_summary(setup)
	if String(metadata.get("template_id", "")) != "translated_rmg_template_043_v1":
		_fail("Extra Large report did not select the translated XL template: %s" % JSON.stringify(metadata))
		return false
	if int(topology.get("zone_count", 0)) < 33 or int(topology.get("link_count", 0)) < 68:
		_fail("Extra Large report used compact topology counts: %s" % JSON.stringify(topology))
		return false
	for phase in phases:
		if not (phase is Dictionary) or String(phase.get("phase", "")) != "template_profile":
			continue
		var summary: Dictionary = phase.get("summary", {}) if phase.get("summary", {}) is Dictionary else {}
		if int(summary.get("zone_count", 0)) < 33 or int(summary.get("link_count", 0)) < 68:
			_fail("Template phase did not expose XL topology: %s" % JSON.stringify(phase))
			return false
		return true
	_fail("Template profile phase was missing from XL materialization report.")
	return false

func _topology_summary(setup: Dictionary) -> Dictionary:
	var generated_map: Dictionary = setup.get("generated_map", {}) if setup.get("generated_map", {}) is Dictionary else {}
	var staging: Dictionary = generated_map.get("staging", {}) if generated_map.get("staging", {}) is Dictionary else {}
	var template: Dictionary = staging.get("template", {}) if staging.get("template", {}) is Dictionary else {}
	return {
		"template_id": generated_map.get("metadata", {}).get("template_id", ""),
		"profile_id": generated_map.get("metadata", {}).get("profile", {}).get("id", ""),
		"zone_count": template.get("zones", []).size(),
		"link_count": template.get("links", []).size(),
		"source_template_index": template.get("import_provenance", {}).get("source_template_index", 0),
	}

func _materialized_counts(setup: Dictionary) -> Dictionary:
	var materialization: Dictionary = setup.get("generated_map", {}).get("runtime_materialization", {}) if setup.get("generated_map", {}).get("runtime_materialization", {}) is Dictionary else {}
	var objects: Dictionary = materialization.get("objects", {}) if materialization.get("objects", {}) is Dictionary else {}
	return {
		"towns": objects.get("towns", []).size(),
		"mines": objects.get("mines", []).size(),
		"dwellings": objects.get("dwellings", []).size(),
		"guards": objects.get("guards", []).size(),
		"rewards": objects.get("rewards", []).size(),
		"object_instances": objects.get("object_instances", []).size(),
	}

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
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	return parsed.duplicate(true) if parsed is Dictionary else {}

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
