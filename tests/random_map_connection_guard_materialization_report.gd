extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_CONNECTION_GUARD_MATERIALIZATION_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = RandomMapGeneratorRulesScript.new()
	var config := _config("connection-guard-materialization-10184")
	var report: Dictionary = generator.connection_guard_materialization_report(config)
	if not bool(report.get("ok", false)):
		_fail("Connection guard materialization report failed: %s" % JSON.stringify(report))
		return
	if not bool(report.get("same_input_connection_guard_materialization_signature_equivalent", false)):
		_fail("Same seed/template did not preserve connection guard materialization signature.")
		return
	if not bool(report.get("changed_seed_changes_connection_guard_materialization_signature", false)):
		_fail("Changed seed did not change connection guard materialization signature for this placement-sensitive template.")
		return

	var generated: Dictionary = generator.generate(config)
	if not bool(generated.get("ok", false)):
		_fail("Generated payload validation failed: %s" % JSON.stringify(generated.get("report", {})))
		return
	var payload: Dictionary = generated.get("generated_map", {})
	var materialization: Dictionary = payload.get("staging", {}).get("connection_guard_materialization", {})
	if not _assert_materialization_payload(materialization):
		return
	if not _assert_route_and_fairness_references(payload, materialization):
		return
	if not _assert_payload_boundaries(payload):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"stable_signature": payload.get("stable_signature", ""),
		"changed_seed_signature": report.get("changed_seed_signature", ""),
		"connection_guard_materialization_signature": materialization.get("connection_guard_materialization_signature", ""),
		"changed_seed_connection_guard_materialization_signature": report.get("changed_seed_connection_guard_materialization_signature", ""),
		"summary": materialization.get("summary", {}),
		"fairness_guard_materialization_summary": payload.get("staging", {}).get("fairness_report", {}).get("guard_pressure", {}).get("connection_guard_materialization_summary", {}),
		"no_ui_save_adoption": payload.get("scenario_record", {}).get("selection", {}).get("availability", {}),
	})])
	get_tree().quit(0)

func _config(seed: String) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "connection_guard_materialization", "width": 26, "height": 18},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
			"guard_strength_profile": "core_low",
		},
	}

func _assert_materialization_payload(materialization: Dictionary) -> bool:
	if String(materialization.get("schema_id", "")) != RandomMapGeneratorRulesScript.CONNECTION_GUARD_MATERIALIZATION_SCHEMA_ID:
		_fail("Missing connection guard materialization schema payload: %s" % JSON.stringify(materialization))
		return false
	var normal_guards: Array = materialization.get("normal_route_guards", [])
	var wide_suppressions: Array = materialization.get("wide_suppressions", [])
	var special_guards: Array = materialization.get("special_guard_gates", [])
	if normal_guards.is_empty() or wide_suppressions.is_empty() or special_guards.is_empty():
		_fail("Expected normal guards, wide suppressions, and special guard gates: %s" % JSON.stringify(materialization.get("summary", {})))
		return false
	for record in normal_guards:
		if not (record is Dictionary):
			_fail("Normal guard record is invalid.")
			return false
		if int(record.get("guard_value", 0)) <= 0 or bool(record.get("source_link", {}).get("wide", false)) or bool(record.get("source_link", {}).get("border_guard", false)):
			_fail("Normal guard materialized from invalid link semantics: %s" % JSON.stringify(record))
			return false
		if record.get("route_cell_anchor_candidate", {}).is_empty() or record.get("monster_category_placeholder", {}).is_empty() or record.get("reward_category_placeholder", {}).is_empty():
			_fail("Normal guard missed anchor or downstream placeholders: %s" % JSON.stringify(record))
			return false
	for record in wide_suppressions:
		if not (record is Dictionary):
			_fail("Wide suppression record is invalid.")
			return false
		if bool(record.get("normal_guard_materialized", true)) or String(record.get("suppression_reason", "")) == "":
			_fail("Wide link did not explicitly suppress normal guard materialization: %s" % JSON.stringify(record))
			return false
	for record in special_guards:
		if not (record is Dictionary):
			_fail("Special guard record is invalid.")
			return false
		if String(record.get("special_guard_type", "")) != "border_guard_gate_placeholder" or not bool(record.get("required_unlock_metadata", {}).get("unlock_required", false)):
			_fail("Border/special guard did not expose gate placeholder unlock semantics: %s" % JSON.stringify(record))
			return false
	return true

func _assert_route_and_fairness_references(payload: Dictionary, materialization: Dictionary) -> bool:
	var materialized_ids := {}
	for record in materialization.get("materialized_records", []):
		if record is Dictionary:
			materialized_ids[String(record.get("id", ""))] = true
	for record in materialization.get("wide_suppressions", []):
		if record is Dictionary:
			materialized_ids[String(record.get("id", ""))] = true
	var route_reference_count := 0
	for edge in payload.get("staging", {}).get("route_graph", {}).get("edges", []):
		if not (edge is Dictionary):
			continue
		for id_value in edge.get("connection_guard_materialization_ids", []):
			if not materialized_ids.has(String(id_value)):
				_fail("Route edge referenced unknown materialization id: %s" % JSON.stringify(edge))
				return false
			route_reference_count += 1
	if route_reference_count < 3:
		_fail("Route graph did not reference enough materialized guard records.")
		return false
	var guard_pressure: Dictionary = payload.get("staging", {}).get("fairness_report", {}).get("guard_pressure", {})
	if guard_pressure.get("connection_guard_materialization_summary", {}).is_empty():
		_fail("Fairness guard pressure did not reference materialization summary.")
		return false
	var fairness_reference_count := 0
	for record in guard_pressure.get("route_guards", []):
		if record is Dictionary:
			fairness_reference_count += record.get("connection_guard_materialization_ids", []).size()
	if fairness_reference_count < 3:
		_fail("Fairness route guard records did not reference materialized guard ids.")
		return false
	var generated_constraints: Dictionary = payload.get("scenario_record", {}).get("generated_constraints", {})
	if generated_constraints.get("connection_guard_materialization", {}).is_empty():
		_fail("Scenario generated_constraints missed connection guard materialization payload.")
		return false
	return true

func _assert_payload_boundaries(payload: Dictionary) -> bool:
	if String(payload.get("write_policy", "")) != "generated_export_record_no_authored_content_write":
		_fail("Generated payload lost staged no-write policy.")
		return false
	var scenario: Dictionary = payload.get("scenario_record", {})
	if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", true)):
		_fail("Connection guard materialization adopted generated map into campaign or skirmish UI.")
		return false
	if scenario.has("save_adoption") or scenario.has("alpha_parity_claim") or payload.has("save_adoption"):
		_fail("Connection guard materialization exposed save/writeback/parity claim metadata.")
		return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
