extends Node

const HeadlessSimulationHarnessRulesScript = preload("res://scripts/core/HeadlessSimulationHarnessRules.gd")
const REPORT_ID := "STRATEGIC_AI_EMERGENCY_DEFENSE_COMMANDER_FIT_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report: Dictionary = HeadlessSimulationHarnessRulesScript.strategic_ai_emergency_defense_commander_fit_case()
	if not _assert_report(report):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0)

func _assert_report(report: Dictionary) -> bool:
	if String(report.get("subsystem_id", "")) != "strategic_ai_emergency_defense_commander_fit":
		_fail("Unexpected subsystem id: %s" % JSON.stringify(report))
		return false
	if String(report.get("status", "")) != "pass":
		_fail("Emergency defense commander-fit case failed: %s" % JSON.stringify(report))
		return false
	var summary: Dictionary = report.get("summary", {}) if report.get("summary", {}) is Dictionary else {}
	if String(summary.get("selected_hero_id", "")) != "hero_sable":
		_fail("Emergency defense did not select hero_sable: %s" % JSON.stringify(summary))
		return false
	if String(summary.get("selected_hero_id", "")) == String(summary.get("rotation_first_hero_id", "")):
		_fail("Emergency defense selected the rotation-first commander: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("commander_fit_bonus", 0)) <= 0:
		_fail("Emergency defense commander-fit bonus missing: %s" % JSON.stringify(summary))
		return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
