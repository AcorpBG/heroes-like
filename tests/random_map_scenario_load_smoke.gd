extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioFactoryScript = preload("res://scripts/core/ScenarioFactory.gd")
const ScenarioRulesScript = preload("res://scripts/core/ScenarioRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "RANDOM_MAP_SCENARIO_LOAD_SMOKE"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_generated_scenario_drafts()
	var config := {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": "scenario-load-smoke-10184",
		"size": {"preset": "scenario_load_smoke", "width": 24, "height": 16},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
		},
	}

	var generator = RandomMapGeneratorRulesScript.new()
	var generated: Dictionary = generator.generate(config)
	if not bool(generated.get("ok", false)):
		_fail("Generated payload validation failed: %s" % JSON.stringify(generated.get("report", {})))
		return
	var payload: Dictionary = generated.get("generated_map", {})
	if not _assert_catalog_backed(payload):
		return

	var scenario: Dictionary = payload.get("scenario_record", {})
	var scenario_id := String(scenario.get("id", ""))
	if not _assert_absent_from_authored_content(scenario_id, "before load"):
		return
	if ContentService.has_generated_scenario_draft(scenario_id):
		_fail("Generated draft registry should be empty before the load smoke.")
		return
	if not _assert_not_selectable(scenario_id, scenario, "before load"):
		return

	var session: SessionStateStoreScript.SessionData = ScenarioFactoryScript.create_generated_draft_session(payload, "normal")
	if session.scenario_id != scenario_id:
		_fail("Generated draft session did not preserve scenario id: %s." % session.scenario_id)
		return
	if not ContentService.has_generated_scenario_draft(scenario_id):
		_fail("Generated draft was not registered for normal scenario lookup.")
		return
	if not _assert_absent_from_authored_content(scenario_id, "after load"):
		return
	if not _assert_generated_boundary(session, payload):
		return
	if not _assert_not_selectable(scenario_id, scenario, "after load"):
		return

	OverworldRulesScript.normalize_overworld_state(session)
	if not _assert_session_overworld(session, scenario, payload.get("terrain_layers_record", {})):
		return
	if not _assert_content_refs_resolve(scenario):
		return
	if not _assert_objective_path(session):
		return

	ContentService.unregister_generated_scenario_draft(scenario_id)
	if ContentService.has_generated_scenario_draft(scenario_id):
		_fail("Generated draft registry did not clear after smoke cleanup.")
		return
	if not _assert_absent_from_authored_content(scenario_id, "after cleanup"):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scenario_id": scenario_id,
		"launch_mode": session.launch_mode,
		"template_id": payload.get("metadata", {}).get("template_id", ""),
		"profile_id": payload.get("metadata", {}).get("profile", {}).get("id", ""),
		"template_source": payload.get("metadata", {}).get("template_selection", {}).get("source", ""),
		"stable_signature": payload.get("stable_signature", ""),
		"map_size": session.overworld.get("map_size", {}),
		"terrain_layer_status": session.overworld.get("terrain_layers", {}).get("terrain_layer_status", ""),
		"town_count": session.overworld.get("towns", []).size(),
		"resource_count": session.overworld.get("resource_nodes", []).size(),
		"encounter_count": session.overworld.get("encounters", []).size(),
		"objective_status": session.scenario_status,
	})])
	get_tree().quit(0)

func _assert_catalog_backed(payload: Dictionary) -> bool:
	var metadata: Dictionary = payload.get("metadata", {})
	if String(metadata.get("template_id", "")) != "border_gate_compact_v1":
		_fail("Generated payload did not preserve the explicit catalog template id.")
		return false
	if String(metadata.get("profile", {}).get("id", "")) != "border_gate_compact_profile_v1":
		_fail("Generated payload did not preserve the explicit catalog profile id.")
		return false
	if String(metadata.get("template_selection", {}).get("source", "")) != "content_catalog":
		_fail("Generated payload used fallback template selection: %s" % JSON.stringify(metadata.get("template_selection", {})))
		return false
	return true

func _assert_absent_from_authored_content(scenario_id: String, phase: String) -> bool:
	if scenario_id == "":
		_fail("Generated scenario id is empty during %s." % phase)
		return false
	if ContentService.has_authored_scenario(scenario_id):
		_fail("Generated scenario id %s appeared in authored content during %s." % [scenario_id, phase])
		return false
	for item in ContentService.load_json(ContentService.SCENARIOS_PATH).get("items", []):
		if item is Dictionary and String(item.get("id", "")) == scenario_id:
			_fail("Generated scenario id %s was found in authored scenarios.json during %s." % [scenario_id, phase])
			return false
	return true

func _assert_not_selectable(scenario_id: String, scenario: Dictionary, phase: String) -> bool:
	var availability: Dictionary = scenario.get("selection", {}).get("availability", {}) if scenario.get("selection", {}) is Dictionary else {}
	if bool(availability.get("campaign", true)) or bool(availability.get("skirmish", true)):
		_fail("Generated draft became campaign/skirmish selectable in payload during %s." % phase)
		return false
	for entry in ScenarioSelectRulesScript.build_skirmish_browser_entries():
		if entry is Dictionary and String(entry.get("scenario_id", "")) == scenario_id:
			_fail("Generated draft appeared in skirmish browser entries during %s." % phase)
			return false
	for campaign in ContentService.load_json(ContentService.CAMPAIGNS_PATH).get("items", []):
		if not (campaign is Dictionary):
			continue
		for campaign_scenario in campaign.get("scenarios", []):
			if campaign_scenario is Dictionary and String(campaign_scenario.get("scenario_id", "")) == scenario_id:
				_fail("Generated draft appeared in campaign content during %s." % phase)
				return false
	return true

func _assert_generated_boundary(session: SessionStateStoreScript.SessionData, payload: Dictionary) -> bool:
	if session.launch_mode != SessionStateStoreScript.LAUNCH_MODE_GENERATED_DRAFT:
		_fail("Generated draft session used campaign/skirmish launch mode: %s." % session.launch_mode)
		return false
	if not bool(session.flags.get("generated_random_map_draft", false)):
		_fail("Generated draft session did not carry generated boundary flag.")
		return false
	var boundary: Dictionary = session.flags.get("generated_random_map_boundary", {})
	if String(boundary.get("write_policy", "")) != "staged_payload_only_no_authored_content_write":
		_fail("Generated draft session lost staged no-write payload policy: %s." % JSON.stringify(boundary))
		return false
	if String(boundary.get("registry_write_policy", "")) != "memory_only_no_authored_json_write":
		_fail("Generated draft registry policy was not memory-only: %s." % JSON.stringify(boundary))
		return false
	if String(boundary.get("menu_policy", "")) != "not_returned_by_authored_scenario_lists":
		_fail("Generated draft menu policy was not preserved: %s." % JSON.stringify(boundary))
		return false
	var session_metadata: Dictionary = session.overworld.get("generated_random_map_metadata", {})
	if String(session_metadata.get("template_id", "")) != String(payload.get("metadata", {}).get("template_id", "")):
		_fail("Generated template provenance was not available in session overworld metadata.")
		return false
	return true

func _assert_session_overworld(session: SessionStateStoreScript.SessionData, scenario: Dictionary, terrain_layers: Dictionary) -> bool:
	var overworld: Dictionary = session.overworld
	if overworld.get("map", []).size() != scenario.get("map", []).size():
		_fail("Session map did not load generated scenario map rows.")
		return false
	if overworld.get("map_size", {}) != scenario.get("map_size", {}):
		_fail("Session map_size did not match generated scenario map_size.")
		return false
	var loaded_layers: Dictionary = overworld.get("terrain_layers", {})
	if loaded_layers.is_empty() or String(loaded_layers.get("id", "")) != String(terrain_layers.get("id", "")):
		_fail("Session terrain layers did not load from generated draft: %s." % JSON.stringify(loaded_layers))
		return false
	for key in ["towns", "resource_nodes", "encounters"]:
		var expected = scenario.get(key, [])
		var actual = overworld.get(String(key), [])
		if expected is Array and actual is Array and actual.size() != expected.size():
			_fail("Session %s count %d did not match generated scenario count %d." % [key, actual.size(), expected.size()])
			return false
	if overworld.get("towns", []).is_empty() or overworld.get("resource_nodes", []).is_empty() or overworld.get("encounters", []).is_empty():
		_fail("Generated session missed towns, resources, or encounters in normal overworld state.")
		return false
	return true

func _assert_content_refs_resolve(scenario: Dictionary) -> bool:
	if ContentService.get_faction(String(scenario.get("player_faction_id", ""))).is_empty():
		_fail("Generated player faction reference did not resolve.")
		return false
	for town in scenario.get("towns", []):
		if town is Dictionary and ContentService.get_town(String(town.get("town_id", ""))).is_empty():
			_fail("Generated town reference did not resolve: %s." % JSON.stringify(town))
			return false
	for node in scenario.get("resource_nodes", []):
		if node is Dictionary and ContentService.get_resource_site(String(node.get("site_id", ""))).is_empty():
			_fail("Generated resource-site reference did not resolve: %s." % JSON.stringify(node))
			return false
	for encounter in scenario.get("encounters", []):
		if encounter is Dictionary and ContentService.get_encounter(String(encounter.get("encounter_id", ""))).is_empty():
			_fail("Generated encounter reference did not resolve: %s." % JSON.stringify(encounter))
			return false
	return true

func _assert_objective_path(session: SessionStateStoreScript.SessionData) -> bool:
	if not ScenarioRulesScript.is_objective_met(session, "generated_primary_town_held", "victory"):
		_fail("Generated objective did not evaluate through ScenarioRules.is_objective_met.")
		return false
	var result: Dictionary = ScenarioRulesScript.evaluate_session(session)
	if String(result.get("status", "")) != "victory" or session.scenario_status != "victory":
		_fail("Generated objective did not complete through ScenarioRules.evaluate_session: %s." % JSON.stringify(result))
		return false
	if session.flags.has("campaign_id") or session.flags.has("campaign_name") or session.flags.has("campaign_chapter_label"):
		_fail("Generated draft evaluation unexpectedly picked up campaign flags: %s." % JSON.stringify(session.flags))
		return false
	return true

func _fail(message: String) -> void:
	ContentService.clear_generated_scenario_drafts()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
