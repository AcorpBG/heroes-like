extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_LARGE_BATCH_PARITY_STRESS_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = RandomMapGeneratorRulesScript.new()
	var report: Dictionary = generator.large_batch_parity_stress_report()
	if not _assert_report(report):
		return
	if not _assert_coverage(report):
		return
	if not _assert_determinism_and_diagnostics(report):
		return
	if not _assert_boundaries(report):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"summary": report.get("summary", {}),
		"coverage": {
			"translated_template_count": report.get("coverage", {}).get("translated_template_count", 0),
			"covered_translated_template_count": report.get("coverage", {}).get("covered_translated_template_count", 0),
			"water_modes": report.get("coverage", {}).get("water_modes", []),
			"level_counts": report.get("coverage", {}).get("level_counts", []),
			"unsupported_warning_count": report.get("coverage", {}).get("unsupported_warning_count", 0),
		},
		"batch_signature": report.get("batch_signature", ""),
		"changed_batch_signature": report.get("changed_batch_signature", ""),
	})])
	get_tree().quit(0)

func _assert_report(report: Dictionary) -> bool:
	if not bool(report.get("ok", false)):
		_fail("Large batch parity stress report failed: %s" % JSON.stringify(report))
		return false
	if String(report.get("schema_id", "")) != RandomMapGeneratorRulesScript.LARGE_BATCH_PARITY_STRESS_REPORT_SCHEMA_ID:
		_fail("Report schema id mismatch: %s" % JSON.stringify(report))
		return false
	if not bool(report.get("same_input_batch_signature_equivalent", false)):
		_fail("Same inputs did not preserve the large batch signature.")
		return false
	if not bool(report.get("changed_case_changes_batch_signature", false)):
		_fail("Changed seeds did not change the large batch signature.")
		return false
	var summary: Dictionary = report.get("summary", {})
	if int(summary.get("case_count", 0)) < 58:
		_fail("Stress corpus did not expand beyond the representative batch: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("hard_blocker_count", -1)) != 0:
		_fail("Stress report exposed hard blockers instead of accepted unsupported warnings: %s" % JSON.stringify(report.get("hard_blockers", [])))
		return false
	if int(summary.get("unsupported_warning_count", 0)) <= 0 or int(summary.get("expected_negative_count", 0)) <= 0:
		_fail("Stress report missed unsupported warning or expected negative evidence: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("bounded_retry_case_count", 0)) <= 0 or int(summary.get("original_failure_count", 0)) <= 0:
		_fail("Stress report missed bounded retry/original failure evidence: %s" % JSON.stringify(summary))
		return false
	return true

func _assert_coverage(report: Dictionary) -> bool:
	var coverage: Dictionary = report.get("coverage", {})
	if not bool(coverage.get("ok", false)):
		_fail("Coverage failed: %s" % JSON.stringify(coverage))
		return false
	if int(coverage.get("translated_template_count", 0)) != 53 or int(coverage.get("covered_translated_template_count", 0)) != 53:
		_fail("Stress fixtures did not cover all translated template records: %s" % JSON.stringify(coverage))
		return false
	if int(coverage.get("translated_family_count", 0)) <= 0 or int(coverage.get("covered_translated_family_count", 0)) != int(coverage.get("translated_family_count", 0)):
		_fail("Stress fixtures did not cover all translated topology families: %s" % JSON.stringify(coverage))
		return false
	for tag in ["land", "islands_water", "underground", "wide_link", "border_guard", "negative_case", "retry_policy", "object_pool_value_weighting", "runtime_materialization"]:
		if tag not in coverage.get("covered_tags", []):
			_fail("Stress fixtures missed tag %s: %s" % [tag, JSON.stringify(coverage)])
			return false
	if "islands" not in coverage.get("water_modes", []) or "land" not in coverage.get("water_modes", []):
		_fail("Stress fixtures missed land/islands water modes: %s" % JSON.stringify(coverage))
		return false
	if "1" not in coverage.get("level_counts", []) or "2" not in coverage.get("level_counts", []):
		_fail("Stress fixtures missed surface/underground level modes: %s" % JSON.stringify(coverage))
		return false
	return true

func _assert_determinism_and_diagnostics(report: Dictionary) -> bool:
	var saw_materialized_identity := false
	var saw_phase_identity := false
	var saw_unsupported_warning := false
	var saw_negative := false
	var saw_retry := false
	for case_result in report.get("case_results", []):
		if not (case_result is Dictionary):
			_fail("Case result was not a dictionary.")
			return false
		if not bool(case_result.get("ok", false)):
			_fail("Case result was not accepted by the stress policy: %s" % JSON.stringify(case_result))
			return false
		var identity: Dictionary = case_result.get("deterministic_output_identity", {})
		if String(identity.get("generated_output_identity_signature", "")) == "" or String(identity.get("identity_signature", "")) == "":
			_fail("Case missed generated-output identity signatures: %s" % JSON.stringify(case_result))
			return false
		if String(identity.get("phase_signature", "")) != "":
			saw_phase_identity = true
		if String(identity.get("materialized_map_signature", "")) != "":
			saw_materialized_identity = true
		var diagnostics: Dictionary = case_result.get("failure_diagnostics", {})
		if String(case_result.get("final_status", "")) == "unsupported_warning":
			saw_unsupported_warning = true
			if String(diagnostics.get("phase", "")) == "" or case_result.get("remediation_hints", []).is_empty():
				_fail("Unsupported warning missed phase diagnostics or remediation hints: %s" % JSON.stringify(case_result))
				return false
			if diagnostics.get("coordinate_context", {}).is_empty():
				_fail("Unsupported warning missed coordinate or constraint context: %s" % JSON.stringify(case_result))
				return false
		if String(case_result.get("final_status", "")) == "expected_negative":
			saw_negative = true
			if String(diagnostics.get("phase", "")) == "":
				_fail("Expected negative case missed original phase diagnostics: %s" % JSON.stringify(case_result))
				return false
		if "retry_policy" in case_result.get("tags", []):
			saw_retry = true
			if case_result.get("original_failure_summary", {}).is_empty() or int(case_result.get("retry_count", 0)) <= 0:
				_fail("Retry case hid original failure or retry count: %s" % JSON.stringify(case_result))
				return false
			if not bool(case_result.get("retry_policy", {}).get("does_not_hide_original_failure", false)):
				_fail("Retry policy did not preserve original failure evidence: %s" % JSON.stringify(case_result))
				return false
	if not (saw_materialized_identity and saw_phase_identity and saw_unsupported_warning and saw_negative and saw_retry):
		_fail("Stress report missed required identity/diagnostic categories.")
		return false
	return true

func _assert_boundaries(report: Dictionary) -> bool:
	var boundaries: Dictionary = report.get("adoption_boundaries", {})
	if bool(boundaries.get("authored_content_writeback", true)) or bool(boundaries.get("campaign_adoption", true)) or bool(boundaries.get("skirmish_runtime_adoption", true)) or bool(boundaries.get("alpha_or_parity_claim", true)):
		_fail("Stress report selected a forbidden adoption/writeback/parity boundary: %s" % JSON.stringify(boundaries))
		return false
	var serialized := JSON.stringify(report).to_lower()
	for forbidden in ["parity_complete", "alpha_complete", "campaign_adoption\":true", "authored_content_writeback\":true"]:
		if serialized.find(forbidden) >= 0:
			_fail("Stress report contains forbidden completion/adoption claim token: %s" % forbidden)
			return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
