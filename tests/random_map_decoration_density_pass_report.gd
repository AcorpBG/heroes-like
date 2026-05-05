extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_DECORATION_DENSITY_PASS_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = RandomMapGeneratorRulesScript.new()
	var config := _config("decoration-density-pass-10184")
	var report: Dictionary = generator.decoration_density_report(config)
	if not bool(report.get("ok", false)):
		_fail("Decoration density report failed: %s" % JSON.stringify(report))
		return
	if not bool(report.get("same_input_decoration_density_signature_equivalent", false)):
		_fail("Same seed/template did not preserve decoration density signature.")
		return
	if bool(report.get("changed_seed_change_required", true)) and not bool(report.get("changed_seed_changes_decoration_density_signature", false)):
		_fail("Changed seed did not change decoration density signature.")
		return

	var generated: Dictionary = generator.generate(config)
	if not bool(generated.get("ok", false)):
		_fail("Generated payload validation failed: %s" % JSON.stringify(generated.get("report", {})))
		return
	var payload: Dictionary = generated.get("generated_map", {})
	var decoration: Dictionary = payload.get("staging", {}).get("decoration_density_pass", {})
	if not _assert_decoration_payload(decoration):
		return
	if not _assert_exclusions_and_references(payload, decoration):
		return
	if not _assert_payload_boundaries(payload):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"stable_signature": payload.get("stable_signature", ""),
		"decoration_density_signature": decoration.get("decoration_density_signature", ""),
		"changed_seed_decoration_density_signature": report.get("changed_seed_decoration_density_signature", ""),
		"summary": decoration.get("summary", {}),
		"zone_density_targets": decoration.get("zone_density_targets", []),
		"path_safety": decoration.get("path_safety_validation", {}),
	})])
	get_tree().quit(0)

func _config(seed: String) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "decoration_density", "width": 26, "height": 18},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
			"guard_strength_profile": "core_low",
		},
	}

func _assert_decoration_payload(decoration: Dictionary) -> bool:
	if String(decoration.get("schema_id", "")) != RandomMapGeneratorRulesScript.DECORATION_DENSITY_PASS_SCHEMA_ID:
		_fail("Missing decoration density schema payload: %s" % JSON.stringify(decoration))
		return false
	var known_ids: Array = decoration.get("known_original_family_ids", [])
	if known_ids.is_empty():
		_fail("Decoration payload did not expose known original family ids.")
		return false
	var records: Array = decoration.get("decoration_records", [])
	if records.is_empty():
		_fail("Expected staged decoration records.")
		return false
	for record in records:
		if not (record is Dictionary):
			_fail("Decoration record is invalid.")
			return false
		if String(record.get("family_id", "")) not in known_ids:
			_fail("Decoration record used unknown original family id: %s" % JSON.stringify(record))
			return false
		if String(record.get("terrain_id", "")) not in record.get("terrain_bias", {}).get("terrain_ids", []):
			_fail("Decoration family was not terrain-biased for the selected terrain: %s" % JSON.stringify(record))
			return false
		if record.get("body_tiles", []).is_empty() or String(record.get("writeout_state", "")).find("no_final") < 0:
			_fail("Decoration record missed body/writeout staging metadata: %s" % JSON.stringify(record))
			return false
	for target in decoration.get("zone_density_targets", []):
		if not (target is Dictionary):
			_fail("Zone density target is invalid.")
			return false
		var placed := int(target.get("placed_count", 0))
		var effective_target := int(target.get("validation_effective_target", target.get("effective_target", 0)))
		var tolerance := int(target.get("tolerance", 0))
		if abs(placed - effective_target) > tolerance:
			_fail("Decoration density outside tolerance: %s" % JSON.stringify(target))
			return false
	if not bool(decoration.get("path_safety_validation", {}).get("ok", false)):
		_fail("Decoration path safety validation failed: %s" % JSON.stringify(decoration.get("path_safety_validation", {})))
		return false
	return true

func _assert_exclusions_and_references(payload: Dictionary, decoration: Dictionary) -> bool:
	var decorated := {}
	for record in decoration.get("decoration_records", []):
		if not (record is Dictionary):
			continue
		for body in record.get("body_tiles", []):
			if body is Dictionary:
				decorated[_point_key(int(body.get("x", 0)), int(body.get("y", 0)))] = String(record.get("id", ""))
	var blocked_required := {}
	for placement in payload.get("staging", {}).get("object_placements", []):
		if not (placement is Dictionary):
			continue
		for body in placement.get("body_tiles", []):
			if body is Dictionary:
				blocked_required[_point_key(int(body.get("x", 0)), int(body.get("y", 0)))] = "object_body"
		for approach in placement.get("approach_tiles", []):
			if approach is Dictionary:
				blocked_required[_point_key(int(approach.get("x", 0)), int(approach.get("y", 0)))] = "object_approach"
	for segment in payload.get("staging", {}).get("road_network", {}).get("road_segments", []):
		if not (segment is Dictionary):
			continue
		for cell in segment.get("cells", []):
			if cell is Dictionary:
				blocked_required[_point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))] = "road"
	for edge in payload.get("staging", {}).get("route_graph", {}).get("edges", []):
		if not (edge is Dictionary):
			continue
		for key in ["from_anchor", "to_anchor", "route_cell_anchor_candidate"]:
			var point: Dictionary = edge.get(key, {}) if edge.get(key, {}) is Dictionary else {}
			if not point.is_empty():
				blocked_required[_point_key(int(point.get("x", 0)), int(point.get("y", 0)))] = key
	for key in decorated.keys():
		if blocked_required.has(String(key)):
			_fail("Decoration blocked reserved cell %s from %s." % [String(key), String(blocked_required[key])])
			return false
	if payload.get("scenario_record", {}).get("generated_constraints", {}).get("decoration_density_pass", {}).is_empty():
		_fail("Scenario generated_constraints missed decoration density pass.")
		return false
	if payload.get("staging", {}).get("decorative_object_staging", []).is_empty():
		_fail("Staging missed decorative object records for downstream consumers.")
		return false
	return true

func _assert_payload_boundaries(payload: Dictionary) -> bool:
	if String(payload.get("write_policy", "")) != "generated_export_record_no_authored_content_write":
		_fail("Generated payload lost staged no-write policy.")
		return false
	var scenario: Dictionary = payload.get("scenario_record", {})
	if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", true)):
		_fail("Decoration density adopted generated map into campaign or skirmish UI.")
		return false
	if scenario.has("save_adoption") or scenario.has("alpha_parity_claim") or payload.has("save_adoption"):
		_fail("Decoration density exposed save/writeback/parity claim metadata.")
		return false
	return true

func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
