extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_VALIDATION_BATCH_RETRY_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = RandomMapGeneratorRulesScript.new()
	var report: Dictionary = generator.validation_batch_retry_report()
	if not _assert_report(report):
		return
	if not _assert_cases(report):
		return
	if not _assert_boundaries(report):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"case_count": report.get("case_count", 0),
		"batch_signature": report.get("batch_signature", ""),
		"changed_batch_signature": report.get("changed_batch_signature", ""),
		"summary": report.get("summary", {}),
		"coverage": report.get("required_case_tag_coverage", {}),
	})])
	get_tree().quit(0)

func _assert_report(report: Dictionary) -> bool:
	if not bool(report.get("ok", false)):
		_fail("Validation batch/retry report failed: %s" % JSON.stringify(report))
		return false
	if String(report.get("schema_id", "")) != RandomMapGeneratorRulesScript.VALIDATION_BATCH_RETRY_REPORT_SCHEMA_ID:
		_fail("Report schema id mismatch: %s" % JSON.stringify(report))
		return false
	if not bool(report.get("same_input_batch_signature_equivalent", false)):
		_fail("Same fixture batch did not preserve the batch signature.")
		return false
	if not bool(report.get("changed_case_changes_batch_signature", false)):
		_fail("Changed fixture seed/case did not change the batch signature.")
		return false
	var summary: Dictionary = report.get("summary", {})
	if int(summary.get("case_count", 0)) < 6 or int(summary.get("successful_case_count", 0)) != int(summary.get("case_count", 0)):
		_fail("Batch did not run all curated cases successfully: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("original_failure_count", 0)) < 1 or int(summary.get("pass_after_retry_count", 0)) < 1:
		_fail("Batch did not preserve failure/retry evidence: %s" % JSON.stringify(summary))
		return false
	if not bool(report.get("required_case_tag_coverage", {}).get("ok", false)):
		_fail("Batch missed required representative fixture coverage: %s" % JSON.stringify(report.get("required_case_tag_coverage", {})))
		return false
	return true

func _assert_cases(report: Dictionary) -> bool:
	var saw_retry := false
	var saw_water := false
	var saw_underground := false
	var saw_border_guard := false
	var saw_wide := false
	var saw_town_mine_dwelling := false
	var saw_skirmish_provenance := false
	for case_result in report.get("case_results", []):
		if not (case_result is Dictionary):
			_fail("Case result was not a dictionary.")
			return false
		if not bool(case_result.get("ok", false)):
			_fail("Case failed: %s" % JSON.stringify(case_result))
			return false
		var identity: Dictionary = case_result.get("deterministic_output_identity", {})
		if String(identity.get("stable_signature", "")) == "" or String(identity.get("identity_signature", "")) == "":
			_fail("Case missed deterministic output identity: %s" % JSON.stringify(case_result))
			return false
		if not bool(case_result.get("required_phase_statuses_present", false)):
			_fail("Case missed required generation phase statuses: %s" % JSON.stringify(case_result.get("phase_statuses", [])))
			return false
		if int(case_result.get("attempt_count", 0)) > int(case_result.get("retry_policy", {}).get("max_attempts", 0)):
			_fail("Case exceeded retry policy bounds: %s" % JSON.stringify(case_result))
			return false
		if String(case_result.get("final_status", "")) == "pass_after_retry":
			saw_retry = true
			if case_result.get("original_failure_summary", {}).is_empty():
				_fail("Retry case hid the original failure: %s" % JSON.stringify(case_result))
				return false
			if int(case_result.get("attempt_count", 0)) != 2 or int(case_result.get("retry_count", 0)) != 1:
				_fail("Retry case did not use one bounded retry: %s" % JSON.stringify(case_result))
				return false
		var tags := {}
		for tag in case_result.get("tags", []):
			tags[String(tag)] = true
		if tags.has("islands_water"):
			saw_water = true
			if _phase_summary(case_result, "roads_rivers_writeout").get("water_overlay_tile_count", 0) <= 0:
				_fail("Water case did not expose water overlay metadata: %s" % JSON.stringify(case_result))
				return false
		if tags.has("underground_deferred_transit"):
			saw_underground = true
			if String(identity.get("stable_signature", "")) == "":
				_fail("Underground case missed stable identity.")
				return false
		if tags.has("border_guard"):
			saw_border_guard = true
			if _phase_summary(case_result, "connection_guard_materialization").get("special_guard_gate_count", 0) <= 0:
				_fail("Border-guard case did not materialize special guard/gate metadata: %s" % JSON.stringify(case_result))
				return false
		if tags.has("wide_link"):
			saw_wide = true
			if _phase_summary(case_result, "connection_guard_materialization").get("wide_suppression_count", 0) <= 0:
				_fail("Wide-link case did not expose wide guard suppression metadata: %s" % JSON.stringify(case_result))
				return false
		if tags.has("town_mine_dwelling"):
			saw_town_mine_dwelling = true
			var town_summary := _phase_summary(case_result, "town_mine_dwelling_placement")
			if int(town_summary.get("town_count", 0)) <= 0 or int(town_summary.get("mine_count", 0)) <= 0 or int(town_summary.get("dwelling_count", 0)) <= 0:
				_fail("Town/mine/dwelling case missed required placement summaries: %s" % JSON.stringify(town_summary))
				return false
		if tags.has("skirmish_provenance"):
			saw_skirmish_provenance = true
			if String(identity.get("scenario_id", "")).find("generated_") != 0:
				_fail("Skirmish provenance case missed generated scenario identity: %s" % JSON.stringify(identity))
				return false
			if ContentService.has_authored_scenario(String(identity.get("scenario_id", ""))):
				_fail("Generated skirmish provenance scenario was written into authored scenarios.")
				return false
	if not (saw_retry and saw_water and saw_underground and saw_border_guard and saw_wide and saw_town_mine_dwelling and saw_skirmish_provenance):
		_fail("Batch missed representative case evidence: %s" % JSON.stringify({
			"retry": saw_retry,
			"water": saw_water,
			"underground": saw_underground,
			"border_guard": saw_border_guard,
			"wide": saw_wide,
			"town_mine_dwelling": saw_town_mine_dwelling,
			"skirmish_provenance": saw_skirmish_provenance,
		}))
		return false
	return true

func _assert_boundaries(report: Dictionary) -> bool:
	var boundaries: Dictionary = report.get("adoption_boundaries", {})
	if bool(boundaries.get("authored_content_writeback", true)) or bool(boundaries.get("campaign_adoption", true)) or bool(boundaries.get("skirmish_runtime_adoption", true)) or bool(boundaries.get("alpha_or_parity_claim", true)):
		_fail("Batch report selected a forbidden adoption/writeback/parity boundary: %s" % JSON.stringify(boundaries))
		return false
	if String(report.get("artifact_write_policy", "")).find("tests_tmp_or_tmp") < 0:
		_fail("Batch report did not constrain optional artifact writes to tests/tmp or /tmp: %s" % String(report.get("artifact_write_policy", "")))
		return false
	var serialized := JSON.stringify(report).to_lower()
	for forbidden in ["parity_complete", "alpha_complete", "campaign_adoption\":true", "authored_content_writeback\":true"]:
		if serialized.find(forbidden) >= 0:
			_fail("Batch report contains forbidden completion/adoption claim token: %s" % forbidden)
			return false
	return true

func _phase_summary(case_result: Dictionary, phase_name: String) -> Dictionary:
	for phase in case_result.get("phase_statuses", []):
		if phase is Dictionary and String(phase.get("phase", "")) == phase_name:
			return phase.get("summary", {}) if phase.get("summary", {}) is Dictionary else {}
	return {}

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
