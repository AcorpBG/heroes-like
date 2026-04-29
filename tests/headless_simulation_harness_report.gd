extends Node

const HeadlessSimulationHarnessRulesScript = preload("res://scripts/core/HeadlessSimulationHarnessRules.gd")
const REPORT_ID := "HEADLESS_SIMULATION_HARNESS_REPORT"
const FORBIDDEN_CLAIM_TOKENS := [
	"manual_play_replacement\":true",
	"alpha_or_parity_claim\":true",
	"parity_complete",
	"alpha_complete",
	"production_ready",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = HeadlessSimulationHarnessRulesScript.build_report()
	if not _assert_report(first):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(HeadlessSimulationHarnessRulesScript.compact_summary(first))])
	get_tree().quit(0)

func _assert_report(first: Dictionary) -> bool:
	if not bool(first.get("ok", false)):
		_fail("Headless simulation harness did not produce an acceptable report: %s" % JSON.stringify(first))
		return false
	if String(first.get("schema_id", "")) != HeadlessSimulationHarnessRulesScript.REPORT_SCHEMA_ID:
		_fail("Headless simulation harness schema mismatch: %s" % JSON.stringify(first))
		return false
	if String(first.get("harness_signature", "")) == "" or not bool(first.get("self_signature_check", false)):
		_fail("Headless simulation harness signature is missing or not reproducible.")
		return false
	var required_subsystems: Array = HeadlessSimulationHarnessRulesScript.REQUIRED_SUBSYSTEM_IDS
	var case_signatures: Dictionary = first.get("case_signatures", {})
	for subsystem_id in required_subsystems:
		if not case_signatures.has(String(subsystem_id)) or String(case_signatures.get(String(subsystem_id), "")) == "":
			_fail("Headless simulation harness missed subsystem signature: %s" % subsystem_id)
			return false
	var statuses := {}
	for simulation_case in first.get("cases", []):
		if not (simulation_case is Dictionary):
			_fail("Headless simulation harness case was not a dictionary.")
			return false
		var status := String(simulation_case.get("status", ""))
		statuses[status] = int(statuses.get(status, 0)) + 1
		if status not in ["pass", "warning", "deferred"]:
			_fail("Headless simulation harness returned unsupported case status: %s / %s" % [simulation_case.get("subsystem_id", ""), status])
			return false
	if int(statuses.get("pass", 0)) <= 0:
		_fail("Headless simulation harness did not pass any mature subsystem.")
		return false
	if int(statuses.get("warning", 0)) <= 0 and int(statuses.get("deferred", 0)) <= 0:
		_fail("Headless simulation harness should expose immature surfaces as warning/deferred evidence.")
		return false
	var policy: Dictionary = first.get("reporting_policy", {})
	if bool(policy.get("manual_play_replacement", true)) or bool(policy.get("automatic_tuning", true)) or bool(policy.get("runtime_balance_changes", true)) or bool(policy.get("authored_content_writeback", true)) or bool(policy.get("generated_campaign_adoption", true)) or bool(policy.get("alpha_or_parity_claim", true)):
		_fail("Headless simulation harness violated report-only boundaries: %s" % JSON.stringify(policy))
		return false
	var serialized := JSON.stringify(HeadlessSimulationHarnessRulesScript.compact_summary(first)).to_lower()
	for token in FORBIDDEN_CLAIM_TOKENS:
		if serialized.find(token) >= 0:
			_fail("Headless simulation compact report contains forbidden claim token: %s" % token)
			return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
