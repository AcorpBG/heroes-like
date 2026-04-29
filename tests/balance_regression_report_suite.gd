extends Node

const BalanceRegressionReportRulesScript = preload("res://scripts/core/BalanceRegressionReportRules.gd")
const REPORT_ID := "BALANCE_REGRESSION_REPORT_SUITE"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var first: Dictionary = BalanceRegressionReportRulesScript.build_report()
	if not _assert_report(first):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(BalanceRegressionReportRulesScript.compact_summary(first))])
	get_tree().quit(0)

func _assert_report(first: Dictionary) -> bool:
	if not bool(first.get("ok", false)):
		_fail("Balance regression report did not produce an acceptable report: %s" % JSON.stringify(first))
		return false
	if String(first.get("schema_id", "")) != BalanceRegressionReportRulesScript.REPORT_SCHEMA_ID:
		_fail("Balance regression report schema mismatch: %s" % JSON.stringify(first))
		return false
	if String(first.get("suite_signature", "")) == "" or not bool(first.get("self_signature_check", false)):
		_fail("Balance regression suite signature is missing or not reproducible from section signatures.")
		return false
	var required_sections: Array = BalanceRegressionReportRulesScript.REQUIRED_SECTION_IDS
	var section_signatures: Dictionary = first.get("section_signatures", {})
	for section_id in required_sections:
		if not section_signatures.has(String(section_id)) or String(section_signatures.get(String(section_id), "")) == "":
			_fail("Balance regression report missing required section signature: %s" % section_id)
			return false
	var statuses := {}
	for section in first.get("sections", []):
		if not (section is Dictionary):
			_fail("Balance regression report section was not a dictionary.")
			return false
		var status := String(section.get("status", ""))
		statuses[status] = int(statuses.get(status, 0)) + 1
		if status not in ["pass", "warning", "deferred"]:
			_fail("Balance regression report section returned unsupported status: %s / %s" % [section.get("section_id", ""), status])
			return false
	if int(statuses.get("pass", 0)) <= 0:
		_fail("Balance regression report did not pass any mature surface.")
		return false
	if int(statuses.get("warning", 0)) <= 0 and int(statuses.get("deferred", 0)) <= 0:
		_fail("Balance regression report should expose immature foundation surfaces as warning/deferred evidence.")
		return false
	var policy: Dictionary = first.get("reporting_policy", {})
	if bool(policy.get("automatic_tuning", true)) or bool(policy.get("runtime_balance_changes", true)) or bool(policy.get("authored_content_writeback", true)) or bool(policy.get("alpha_or_parity_claim", true)):
		_fail("Balance regression report violated report-only boundaries: %s" % JSON.stringify(policy))
		return false
	var serialized := JSON.stringify(BalanceRegressionReportRulesScript.compact_summary(first)).to_lower()
	for forbidden in ["automatic_tuning\":true", "alpha_or_parity_claim\":true", "parity_complete", "alpha_complete", "production_ready"]:
		if serialized.find(forbidden) >= 0:
			_fail("Balance regression compact report contains forbidden claim token: %s" % forbidden)
			return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
