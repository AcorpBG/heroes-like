extends Node

const SourceReportScript = preload("res://tests/magic_ai_valuation_casting_hooks_report.gd")
const REPORT_ID := "MAGIC_PRISM_BASTION_ROOT_COUNTERCONTROL_REGRESSION"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var source_report := SourceReportScript.new()
	var result: Dictionary = source_report._run_battle_ai_cleanse_active_ward_case()
	source_report.free()
	if not bool(result.get("ok", false)) or not bool(result.get("target_had_rooted_status", false)):
		print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "result": result})])
		get_tree().quit(1)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "result": result})])
	get_tree().quit(0)
