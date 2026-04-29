extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_SEEDED_GENERATOR_CORE_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": "seeded-core-10184",
		"size": {"preset": "core_test", "width": 18, "height": 12},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "seeded_core_test_profile",
			"label": "Seeded Core Test Profile",
			"terrain_ids": ["grass", "plains", "forest", "swamp", "highland"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
			"guard_strength_profile": "core_low",
		},
	}

	var generator = RandomMapGeneratorRulesScript.new()
	var report: Dictionary = generator.seed_determinism_report(config)
	if not bool(report.get("ok", false)):
		_fail("Determinism report failed: %s" % JSON.stringify(report))
		return
	if not bool(report.get("same_input_payload_equivalent", false)):
		_fail("Same input did not produce byte-stable equivalent generated payload.")
		return
	if not bool(report.get("same_input_signature_equivalent", false)):
		_fail("Same input did not produce the same stable signature.")
		return
	if not bool(report.get("changed_seed_changes_payload", false)):
		_fail("Changed seed did not change generated payload signature.")
		return
	if String(report.get("generator_version", "")) != RandomMapGeneratorRulesScript.GENERATOR_VERSION:
		_fail("Report did not expose normalized generator version.")
		return
	if String(report.get("normalized_seed", "")) != "seeded-core-10184":
		_fail("Report did not expose normalized seed.")
		return

	var generated: Dictionary = generator.generate(config)
	var payload: Dictionary = generated.get("generated_map", {})
	if not bool(generated.get("ok", false)):
		_fail("Generated payload validation failed: %s" % JSON.stringify(generated.get("report", {})))
		return
	if not _assert_payload_boundary(payload):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"schema_id": report.get("schema_id", ""),
		"generator_version": report.get("generator_version", ""),
		"normalized_seed": report.get("normalized_seed", ""),
		"profile_id": report.get("profile_id", ""),
		"stable_signature": report.get("stable_signature", ""),
		"changed_seed_signature": report.get("changed_seed_signature", ""),
		"validation": generated.get("report", {}),
		"determinism_sources_excluded": report.get("determinism_sources_excluded", []),
	})])
	get_tree().quit(0)

func _assert_payload_boundary(payload: Dictionary) -> bool:
	if String(payload.get("schema_id", "")) != RandomMapGeneratorRulesScript.PAYLOAD_SCHEMA_ID:
		_fail("Generated payload schema mismatch.")
		return false
	if String(payload.get("write_policy", "")) != "staged_payload_only_no_authored_content_write":
		_fail("Generated payload lost no-write staging boundary.")
		return false
	var metadata: Dictionary = payload.get("metadata", {})
	for key in ["generator_version", "normalized_seed", "content_manifest_fingerprint", "template_id"]:
		if String(metadata.get(key, "")).strip_edges() == "":
			_fail("Generated metadata missed %s." % key)
			return false
	var staging: Dictionary = payload.get("staging", {})
	if String(staging.get("editable_grid_model", "")) != "terrain_owner_grid_rows_plus_separate_object_placement_arrays":
		_fail("Generated staging payload is not editable terrain-owner grid plus separate placements.")
		return false
	if not (staging.get("terrain_owner_grid", []) is Array) or staging.get("terrain_owner_grid", []).is_empty():
		_fail("Generated staging payload missed terrain owner grid.")
		return false
	if not (staging.get("object_placements", []) is Array) or staging.get("object_placements", []).is_empty():
		_fail("Generated staging payload missed separate object placements.")
		return false
	var route_graph: Dictionary = staging.get("route_graph", {})
	if not (route_graph.get("edges", []) is Array) or route_graph.get("edges", []).is_empty():
		_fail("Generated staging payload missed route graph edges.")
		return false
	var scenario: Dictionary = payload.get("scenario_record", {})
	var rows: Array = scenario.get("map", [])
	if rows.size() != 12 or not (rows[0] is Array) or rows[0].size() != 18:
		_fail("Scenario-like terrain rows did not match requested size.")
		return false
	if scenario.get("towns", []).is_empty() or scenario.get("resource_nodes", []).is_empty() or scenario.get("encounters", []).is_empty():
		_fail("Scenario-like payload did not expose towns, resources, and encounters as separate placement arrays.")
		return false
	if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", true)):
		_fail("Generated scenario draft must not be campaign/skirmish selectable in this slice.")
		return false
	var phase_names := []
	for phase in payload.get("phase_pipeline", []):
		if phase is Dictionary:
			phase_names.append(String(phase.get("phase", "")))
	for required_phase in ["template_profile", "runtime_zone_graph", "zone_seed_layout", "terrain_owner_grid", "object_placement_staging"]:
		if required_phase not in phase_names:
			_fail("Generated phase pipeline missed %s." % required_phase)
			return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
