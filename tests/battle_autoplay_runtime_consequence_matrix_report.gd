extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")

const REPORT_ID := "BATTLE_AUTOPLAY_RUNTIME_CONSEQUENCE_MATRIX_REPORT"
const REQUIRED_MATRIX_SCHEMA := "battle_autoplay_runtime_consequence_matrix_v1"
const REQUIRED_MATRIX_GATE_POLICY := "report_only_runtime_consequence_matrix_thresholds_v1"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report: Dictionary = BattleAutoplayBalanceHarnessRulesScript.build_sampling_report()
	var repeat_report: Dictionary = BattleAutoplayBalanceHarnessRulesScript.build_sampling_report()
	var summary: Dictionary = report.get("summary", {}) if report.get("summary", {}) is Dictionary else {}
	var repeat_summary: Dictionary = repeat_report.get("summary", {}) if repeat_report.get("summary", {}) is Dictionary else {}
	var matrix: Dictionary = summary.get("runtime_consequence_matrix", {}) if summary.get("runtime_consequence_matrix", {}) is Dictionary else {}
	var repeat_matrix: Dictionary = repeat_summary.get("runtime_consequence_matrix", {}) if repeat_summary.get("runtime_consequence_matrix", {}) is Dictionary else {}
	var gate: Dictionary = summary.get("runtime_consequence_matrix_gate", {}) if summary.get("runtime_consequence_matrix_gate", {}) is Dictionary else {}
	var distribution: Dictionary = summary.get("runtime_consequence_distribution", {}) if summary.get("runtime_consequence_distribution", {}) is Dictionary else {}
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"matrix_schema": String(matrix.get("schema", "")),
		"gate_policy": String(gate.get("policy", "")),
		"gate_status": String(gate.get("status", "")),
		"sample_count": int(matrix.get("sample_count", 0)),
		"distribution_signature": String(distribution.get("distribution_signature", "")),
		"matrix_signature": String(matrix.get("matrix_signature", "")),
		"repeat_matrix_signature": String(repeat_matrix.get("matrix_signature", "")),
		"difficulty_cohort_count": int(gate.get("difficulty_cohort_count", 0)),
		"terrain_cohort_count": int(gate.get("terrain_cohort_count", 0)),
		"scenario_cohort_count": int(gate.get("scenario_cohort_count", 0)),
		"matchup_cohort_count": int(gate.get("matchup_cohort_count", 0)),
		"ability_presence_cohort_count": int(gate.get("ability_presence_cohort_count", 0)),
		"ability_consequence_cohort_count": int(gate.get("ability_consequence_cohort_count", 0)),
		"zero_consequence_sample_count": int(gate.get("zero_consequence_sample_count", -1)),
		"gate_warnings": gate.get("warnings", []),
		"gate_failures": gate.get("failures", []),
	}
	if String(matrix.get("schema", "")) != REQUIRED_MATRIX_SCHEMA:
		_fail("Runtime consequence matrix schema missing.", payload)
		return
	if String(gate.get("policy", "")) != REQUIRED_MATRIX_GATE_POLICY:
		_fail("Runtime consequence matrix gate policy missing.", payload)
		return
	if String(matrix.get("matrix_signature", "")) == "" or String(matrix.get("matrix_signature", "")) != String(repeat_matrix.get("matrix_signature", "")):
		_fail("Runtime consequence matrix signature is missing or non-deterministic.", payload)
		return
	if String(gate.get("status", "")) != "pass":
		_fail("Runtime consequence matrix gate did not pass.", payload)
		return
	if int(matrix.get("sample_count", 0)) != int(summary.get("sample_count", -1)):
		_fail("Runtime consequence matrix sample count does not match summary.", payload)
		return
	if int(gate.get("zero_consequence_sample_count", -1)) != 0:
		_fail("Runtime consequence matrix found sampled battles with no runtime consequence evidence.", payload)
		return
	for section_id in ["difficulty", "terrain", "scenario", "matchup", "ability_presence"]:
		if not _assert_section(section_id, matrix, payload):
			return
	var scenario: Dictionary = matrix.get("scenario", {}) if matrix.get("scenario", {}) is Dictionary else {}
	for required_scenario in BattleAutoplayBalanceHarnessRulesScript.DEFAULT_SCENARIO_IDS:
		if not scenario.has(String(required_scenario)):
			_fail("Runtime consequence matrix missing sampled scenario cohort: %s" % String(required_scenario), payload)
			return
	var difficulty: Dictionary = matrix.get("difficulty", {}) if matrix.get("difficulty", {}) is Dictionary else {}
	for required_difficulty in ["low", "medium", "high"]:
		if not difficulty.has(required_difficulty):
			_fail("Runtime consequence matrix missing difficulty cohort: %s" % required_difficulty, payload)
			return
	if int(gate.get("ability_consequence_cohort_count", 0)) <= 0:
		_fail("Runtime consequence matrix did not retain any ability-presence cohort with ability consequences.", payload)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_section(section_id: String, matrix: Dictionary, payload: Dictionary) -> bool:
	var section: Dictionary = matrix.get(section_id, {}) if matrix.get(section_id, {}) is Dictionary else {}
	if section.is_empty():
		_fail("Runtime consequence matrix missing section: %s" % section_id, payload)
		return false
	for cohort_id in section.keys():
		var cohort: Dictionary = section.get(cohort_id, {}) if section.get(cohort_id, {}) is Dictionary else {}
		if int(cohort.get("sample_count", 0)) <= 0:
			_fail("Runtime consequence matrix cohort lacks samples: %s/%s" % [section_id, String(cohort_id)], payload)
			return false
		if String(cohort.get("cohort_signature", "")) == "":
			_fail("Runtime consequence matrix cohort lacks deterministic signature: %s/%s" % [section_id, String(cohort_id)], payload)
			return false
		if int(cohort.get("samples_with_status_consequence_count", 0)) <= 0:
			_fail("Runtime consequence matrix cohort lacks status consequence evidence: %s/%s" % [section_id, String(cohort_id)], payload)
			return false
		if not _array_contains_string(cohort.get("observed_event_ids", []), "battle_status_applied"):
			_fail("Runtime consequence matrix cohort lacks status event evidence: %s/%s" % [section_id, String(cohort_id)], payload)
			return false
	return true

func _array_contains_string(value: Variant, expected: String) -> bool:
	if not (value is Array):
		return false
	for item in value:
		if String(item) == expected:
			return true
	return false

func _fail(message: String, payload: Dictionary) -> void:
	payload["ok"] = false
	payload["error"] = message
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
