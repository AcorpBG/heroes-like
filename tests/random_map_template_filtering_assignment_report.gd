extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_TEMPLATE_FILTERING_ASSIGNMENT_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = RandomMapGeneratorRulesScript.new()
	if not _assert_invalid_requests_reject(generator):
		return
	var xl_topology := _assert_extra_large_template_selection(generator)
	if xl_topology.is_empty():
		return
	var base_config := {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": "filtering-assignment-10184",
		"size": {"preset": "filtering_assignment", "width": 36, "height": 30, "water_mode": "land", "level_count": 1},
		"player_constraints": {"human_count": 2, "player_count": 4, "team_mode": "free_for_all"},
		"profile": {
			"id": "translated_rmg_profile_001_v1",
			"template_id": "translated_rmg_template_001_v1",
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
	}
	var first: Dictionary = generator.generate(base_config)
	var second: Dictionary = generator.generate(base_config)
	var changed_config := base_config.duplicate(true)
	changed_config["seed"] = "filtering-assignment-10184-changed"
	var changed: Dictionary = generator.generate(changed_config)
	var payload: Dictionary = first.get("generated_map", {})
	var repeated_payload: Dictionary = second.get("generated_map", {})
	var changed_payload: Dictionary = changed.get("generated_map", {})
	if payload.is_empty() or repeated_payload.is_empty() or changed_payload.is_empty():
		_fail("Valid imported template selection did not produce generated payloads: %s / %s / %s" % [JSON.stringify(first.get("report", {})), JSON.stringify(second.get("report", {})), JSON.stringify(changed.get("report", {}))])
		return
	if String(payload.get("stable_signature", "")) != String(repeated_payload.get("stable_signature", "")):
		_fail("Same seed/template/profile/player constraints did not remain stable.")
		return
	if String(payload.get("stable_signature", "")) == String(changed_payload.get("stable_signature", "")):
		_fail("Changed seed did not alter generated assignment/layout signature.")
		return
	if not _assert_selection_metadata(payload):
		return
	if not _assert_assignment_payload(payload):
		return
	if not _assert_runtime_zone_assignment(payload):
		return
	if not _assert_scenario_boundary(payload):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"template_id": payload.get("metadata", {}).get("template_id", ""),
		"stable_signature": payload.get("stable_signature", ""),
		"changed_seed_signature": changed_payload.get("stable_signature", ""),
		"selection": payload.get("metadata", {}).get("template_selection", {}),
		"extra_large_topology": xl_topology,
		"assignment": payload.get("staging", {}).get("player_assignment", {}),
		"towns": payload.get("scenario_record", {}).get("towns", []),
		"no_ui_save_adoption": payload.get("scenario_record", {}).get("selection", {}).get("availability", {}),
	})])
	get_tree().quit(0)

func _assert_invalid_requests_reject(generator) -> bool:
	var invalid_cases := [
		{
			"name": "explicit_size",
			"config": _invalid_config({
				"size": {"preset": "too_large_for_template", "width": 64, "height": 48, "water_mode": "land", "level_count": 2},
				"profile": {"id": "translated_rmg_profile_001_v1", "template_id": "translated_rmg_template_001_v1"},
			}),
			"expected_reason": "size_score",
		},
		{
			"name": "explicit_water",
			"config": _invalid_config({"size": {"preset": "water_reject", "width": 24, "height": 16, "water_mode": "islands", "level_count": 1}, "profile": {"id": "border_gate_compact_profile_v1", "template_id": "border_gate_compact_v1"}}),
			"expected_reason": "water_mode",
		},
		{
			"name": "explicit_players",
			"config": _invalid_config({"player_constraints": {"human_count": 2, "player_count": 3}}),
			"expected_reason": "human_count",
		},
		{
			"name": "explicit_template",
			"config": _invalid_config({"template_id": "missing_template_for_rejection_report"}),
			"expected_reason": "not found",
		},
	]
	for invalid_case in invalid_cases:
		var generated: Dictionary = generator.generate(invalid_case.get("config", {}))
		if bool(generated.get("ok", true)):
			_fail("Invalid %s request unexpectedly generated a payload." % String(invalid_case.get("name", "")))
			return false
		var report: Dictionary = generated.get("report", {})
		if String(report.get("schema_id", "")) != RandomMapGeneratorRulesScript.TEMPLATE_SELECTION_REJECTION_SCHEMA_ID:
			_fail("Invalid %s request did not return structured template rejection: %s" % [String(invalid_case.get("name", "")), JSON.stringify(report)])
			return false
		if String(report.get("template_selection", {}).get("source", "")).begins_with("built_in_fallback"):
			_fail("Invalid %s request silently fell back: %s" % [String(invalid_case.get("name", "")), JSON.stringify(report)])
			return false
		var reason_text := JSON.stringify(report.get("failures", []))
		if not reason_text.contains(String(invalid_case.get("expected_reason", ""))):
			_fail("Invalid %s rejection did not expose expected reason %s: %s" % [String(invalid_case.get("name", "")), String(invalid_case.get("expected_reason", "")), reason_text])
			return false
	return true

func _assert_extra_large_template_selection(generator) -> Dictionary:
	var config := {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": "filtering-assignment-10184-xl",
		"size": {"preset": "filtering_assignment_xl", "source_width": 144, "source_height": 144, "width": 144, "height": 144, "water_mode": "land", "level_count": 1},
		"player_constraints": {"human_count": 1, "player_count": 4, "team_mode": "free_for_all"},
		"profile": {
			"id": "translated_rmg_profile_043_v1",
			"template_id": "translated_rmg_template_043_v1",
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
	}
	var generated: Dictionary = generator.generate(config)
	if not bool(generated.get("ok", false)):
		_fail("XL translated template selection did not validate: %s" % JSON.stringify(generated.get("report", {})))
		return {}
	var payload: Dictionary = generated.get("generated_map", {}) if generated.get("generated_map", {}) is Dictionary else {}
	var metadata: Dictionary = payload.get("metadata", {}) if payload.get("metadata", {}) is Dictionary else {}
	var selection: Dictionary = metadata.get("template_selection", {}) if metadata.get("template_selection", {}) is Dictionary else {}
	var constraint_report: Dictionary = selection.get("constraint_report", {}) if selection.get("constraint_report", {}) is Dictionary else {}
	var requested: Dictionary = constraint_report.get("requested", {}) if constraint_report.get("requested", {}) is Dictionary else {}
	var template: Dictionary = payload.get("staging", {}).get("template", {}) if payload.get("staging", {}).get("template", {}) is Dictionary else {}
	if String(metadata.get("template_id", "")) != "translated_rmg_template_043_v1":
		_fail("XL selection chose the wrong template: %s" % JSON.stringify(metadata))
		return {}
	if int(requested.get("size_score", 0)) != 16:
		_fail("XL selection did not request size_score 16: %s" % JSON.stringify(selection))
		return {}
	if template.get("zones", []).size() < 33 or template.get("links", []).size() < 68:
		_fail("XL selection used compact topology: %s" % JSON.stringify(template.get("graph_summary", {})))
		return {}
	return {
		"template_id": String(metadata.get("template_id", "")),
		"profile_id": String(metadata.get("profile", {}).get("id", "")),
		"size_score": int(requested.get("size_score", 0)),
		"zone_count": template.get("zones", []).size(),
		"link_count": template.get("links", []).size(),
		"source_template_index": template.get("import_provenance", {}).get("source_template_index", 0),
	}

func _invalid_config(overrides: Dictionary) -> Dictionary:
	var config := {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": "filtering-assignment-invalid",
		"size": {"preset": "filtering_assignment_invalid", "width": 24, "height": 16, "water_mode": "land", "level_count": 1},
		"player_constraints": {"human_count": 1, "player_count": 3},
		"profile": {"id": "border_gate_compact_profile_v1", "template_id": "border_gate_compact_v1"},
	}
	for key in overrides.keys():
		config[key] = overrides[key]
	return config

func _assert_selection_metadata(payload: Dictionary) -> bool:
	var selection: Dictionary = payload.get("metadata", {}).get("template_selection", {})
	if String(selection.get("source", "")) != "content_catalog" or bool(selection.get("rejected", true)):
		_fail("Valid imported template did not select through catalog: %s" % JSON.stringify(selection))
		return false
	var requested: Dictionary = selection.get("constraint_report", {}).get("requested", {})
	if int(requested.get("human_count", 0)) != 2 or int(requested.get("player_count", 0)) != 4:
		_fail("Selection report did not preserve requested player constraints: %s" % JSON.stringify(selection))
		return false
	if String(requested.get("water_mode", "")) != "land" or int(requested.get("level_count", 0)) != 1:
		_fail("Selection report did not preserve water/level constraints: %s" % JSON.stringify(selection))
		return false
	return true

func _assert_assignment_payload(payload: Dictionary) -> bool:
	var assignment: Dictionary = payload.get("staging", {}).get("player_assignment", {})
	if String(assignment.get("schema_id", "")) != "random_map_player_assignment_v1":
		_fail("Staging missed player assignment payload: %s" % JSON.stringify(assignment))
		return false
	if int(assignment.get("human_count", 0)) != 2 or int(assignment.get("player_count", 0)) != 4:
		_fail("Assignment counts do not match request: %s" % JSON.stringify(assignment))
		return false
	if assignment.get("player_slots", []).size() != 4 or assignment.get("active_owner_slots", []).size() != 4:
		_fail("Fixed owner slots were not mapped to requested player slots: %s" % JSON.stringify(assignment))
		return false
	if String(assignment.get("team_metadata", {}).get("mode", "")) != "free_for_all":
		_fail("Assignment did not expose free-for-all team metadata: %s" % JSON.stringify(assignment))
		return false
	for slot in assignment.get("player_slots", []):
		if not (slot is Dictionary):
			_fail("Assignment contains non-dictionary slot: %s" % JSON.stringify(assignment))
			return false
		if String(slot.get("faction_id", "")) not in assignment.get("faction_pool", []):
			_fail("Assigned faction was outside profile/template faction pool: %s" % JSON.stringify(slot))
			return false
	return true

func _assert_runtime_zone_assignment(payload: Dictionary) -> bool:
	var active_zones := 0
	for zone in payload.get("staging", {}).get("zones", []):
		if not (zone is Dictionary) or zone.get("player_slot", null) == null:
			continue
		active_zones += 1
		if int(zone.get("owner_slot", 0)) != int(zone.get("player_slot", 0)):
			_fail("Fixed owner slot did not map to the same player slot: %s" % JSON.stringify(zone))
			return false
		if String(zone.get("faction_id", "")) == "" or String(zone.get("team_id", "")) == "":
			_fail("Assigned runtime zone missed faction/team metadata: %s" % JSON.stringify(zone))
			return false
	if active_zones != 4:
		_fail("Runtime zones did not expose four active assigned starts.")
		return false
	var towns: Array = payload.get("scenario_record", {}).get("towns", [])
	if towns.size() != 4:
		_fail("Scenario record did not contain one town for each active assigned player: %s" % JSON.stringify(towns))
		return false
	for town in towns:
		if not (town is Dictionary) or String(town.get("faction_id", "")) == "" or String(town.get("team_id", "")) == "":
			_fail("Scenario town missed faction/team assignment: %s" % JSON.stringify(town))
			return false
	return true

func _assert_scenario_boundary(payload: Dictionary) -> bool:
	var scenario: Dictionary = payload.get("scenario_record", {})
	if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", true)):
		_fail("Filtering/assignment slice adopted generated maps into campaign or skirmish UI.")
		return false
	if scenario.has("save_adoption") or scenario.has("alpha_parity_claim"):
		_fail("Scenario record exposed a save adoption or parity claim field.")
		return false
	if scenario.get("players", []).size() != 4 or scenario.get("generated_player_assignment", {}).is_empty():
		_fail("Scenario record missed generated player assignment metadata.")
		return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
