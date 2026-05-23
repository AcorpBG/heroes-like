extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")

const REPORT_ID := "BATTLE_AUTOPLAY_RUNTIME_CONSEQUENCE_REPORT"
const REQUIRED_PROFILE_SCHEMA := "battle_autoplay_runtime_consequence_profile_v1"
const REQUIRED_DISTRIBUTION_SCHEMA := "battle_autoplay_runtime_consequence_distribution_v1"
const REQUIRED_GATE_POLICY := "report_only_runtime_consequence_thresholds_v1"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report: Dictionary = BattleAutoplayBalanceHarnessRulesScript.build_sampling_report()
	var repeat_report: Dictionary = BattleAutoplayBalanceHarnessRulesScript.build_sampling_report()
	var summary: Dictionary = report.get("summary", {}) if report.get("summary", {}) is Dictionary else {}
	var repeat_summary: Dictionary = repeat_report.get("summary", {}) if repeat_report.get("summary", {}) is Dictionary else {}
	var distribution: Dictionary = summary.get("runtime_consequence_distribution", {}) if summary.get("runtime_consequence_distribution", {}) is Dictionary else {}
	var repeat_distribution: Dictionary = repeat_summary.get("runtime_consequence_distribution", {}) if repeat_summary.get("runtime_consequence_distribution", {}) is Dictionary else {}
	var gate: Dictionary = summary.get("runtime_consequence_gate", {}) if summary.get("runtime_consequence_gate", {}) is Dictionary else {}
	var samples: Array = report.get("samples", []) if report.get("samples", []) is Array else []
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"profile_schema": REQUIRED_PROFILE_SCHEMA,
		"distribution_schema": String(distribution.get("schema", "")),
		"gate_policy": String(gate.get("policy", "")),
		"gate_status": String(gate.get("status", "")),
		"sample_count": int(distribution.get("sample_count", 0)),
		"samples_with_status_consequence_count": int(distribution.get("samples_with_status_consequence_count", 0)),
		"samples_with_ability_consequence_count": int(distribution.get("samples_with_ability_consequence_count", 0)),
		"samples_with_spell_consequence_count": int(distribution.get("samples_with_spell_consequence_count", 0)),
		"total_status_application_event_count": int(distribution.get("total_status_application_event_count", 0)),
		"total_ability_effect_observation_count": int(distribution.get("total_ability_effect_observation_count", 0)),
		"total_spell_effect_observation_count": int(distribution.get("total_spell_effect_observation_count", 0)),
		"observed_event_ids": distribution.get("observed_event_ids", []),
		"observed_effect_ids": distribution.get("observed_effect_ids", []),
		"observed_source_types": distribution.get("observed_source_types", []),
		"distribution_signature": String(distribution.get("distribution_signature", "")),
		"repeat_distribution_signature": String(repeat_distribution.get("distribution_signature", "")),
		"gate_failures": gate.get("failures", []),
	}
	if String(distribution.get("schema", "")) != REQUIRED_DISTRIBUTION_SCHEMA:
		_fail("Runtime consequence distribution schema missing.", payload)
		return
	if String(gate.get("policy", "")) != REQUIRED_GATE_POLICY:
		_fail("Runtime consequence gate policy missing.", payload)
		return
	if String(distribution.get("distribution_signature", "")) == "" or String(distribution.get("distribution_signature", "")) != String(repeat_distribution.get("distribution_signature", "")):
		_fail("Runtime consequence distribution signature is missing or non-deterministic.", payload)
		return
	if String(gate.get("status", "")) != "pass":
		_fail("Runtime consequence gate did not pass.", payload)
		return
	if int(distribution.get("sample_count", 0)) != int(summary.get("sample_count", -1)):
		_fail("Runtime consequence sample count does not match summary sample count.", payload)
		return
	if int(distribution.get("total_status_application_event_count", 0)) <= 0:
		_fail("Autoplay samples did not observe any status application events.", payload)
		return
	if int(distribution.get("samples_with_ability_consequence_count", 0)) <= 0:
		_fail("Autoplay samples did not observe ability-driven runtime consequences.", payload)
		return
	if not _array_contains_string(distribution.get("observed_source_types", []), "ability"):
		_fail("Runtime consequence distribution did not retain ability effect source evidence.", payload)
		return
	if not _array_contains_string(distribution.get("observed_event_ids", []), "battle_status_applied"):
		_fail("Runtime consequence distribution did not retain status-application event evidence.", payload)
		return
	if not _assert_sample_profiles(samples, payload):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_sample_profiles(samples: Array, payload: Dictionary) -> bool:
	var saw_ability_consequence := false
	for sample in samples:
		if not (sample is Dictionary):
			continue
		var profile: Dictionary = sample.get("runtime_consequence_profile", {}) if sample.get("runtime_consequence_profile", {}) is Dictionary else {}
		if String(profile.get("schema", "")) != REQUIRED_PROFILE_SCHEMA:
			_fail("Sample runtime consequence profile schema missing.", payload)
			return false
		if String(profile.get("profile_signature", "")) == "":
			_fail("Sample runtime consequence profile signature missing.", payload)
			return false
		if bool(profile.get("has_ability_consequence", false)):
			saw_ability_consequence = true
			if int(profile.get("ability_effect_observation_count", 0)) <= 0:
				_fail("Ability consequence sample lacks ability effect observations.", payload)
				return false
	if not saw_ability_consequence:
		_fail("No sample profile reported an ability consequence.", payload)
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
