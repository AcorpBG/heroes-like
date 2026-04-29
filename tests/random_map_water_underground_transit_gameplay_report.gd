extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_WATER_UNDERGROUND_TRANSIT_GAMEPLAY_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = RandomMapGeneratorRulesScript.new()
	var report: Dictionary = generator.water_underground_transit_gameplay_report()
	if not _assert_report(report):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"water_signature": report.get("water_signature", ""),
		"underground_signature": report.get("underground_signature", ""),
		"water_summary": report.get("water_case", {}).get("summary", {}),
		"underground_summary": report.get("underground_case", {}).get("summary", {}),
		"boundaries": report.get("boundaries", {}),
	})])
	get_tree().quit(0)

func _assert_report(report: Dictionary) -> bool:
	if not bool(report.get("ok", false)):
		_fail("Water/underground transit report failed: %s" % JSON.stringify(report))
		return false
	if String(report.get("schema_id", "")) != RandomMapGeneratorRulesScript.WATER_UNDERGROUND_TRANSIT_GAMEPLAY_REPORT_SCHEMA_ID:
		_fail("Report schema id mismatch: %s" % JSON.stringify(report))
		return false
	if not bool(report.get("same_input_water_signature_equivalent", false)) or not bool(report.get("same_input_underground_signature_equivalent", false)):
		_fail("Same-input transit signatures were not stable.")
		return false
	if not bool(report.get("changed_seed_changes_water_signature", false)) or not bool(report.get("changed_seed_changes_underground_signature", false)):
		_fail("Changed seed did not change water/underground transit signatures.")
		return false
	var water: Dictionary = report.get("water_case", {}) if report.get("water_case", {}) is Dictionary else {}
	var underground: Dictionary = report.get("underground_case", {}) if report.get("underground_case", {}) is Dictionary else {}
	if int(water.get("summary", {}).get("water_transit_count", 0)) <= 0:
		_fail("Island/water case missed materialized ferry/bridge transit records.")
		return false
	if int(underground.get("summary", {}).get("cross_level_link_count", 0)) <= 0 or int(underground.get("summary", {}).get("underground_level_count", 0)) <= 0:
		_fail("Underground case missed materialized cross-level links or level records.")
		return false
	if int(water.get("runtime_materialization_summary", {}).get("transit_count", 0)) <= 0:
		_fail("Runtime materialization missed water transit records.")
		return false
	if int(underground.get("runtime_materialization_summary", {}).get("transit_count", 0)) <= 0:
		_fail("Runtime materialization missed cross-level transit records.")
		return false
	var boundaries: Dictionary = report.get("boundaries", {}) if report.get("boundaries", {}) is Dictionary else {}
	if bool(boundaries.get("campaign_adoption", true)) or bool(boundaries.get("authored_content_writeback", true)) or bool(boundaries.get("parity_or_alpha_claim", true)):
		_fail("Report violated campaign/writeback/parity boundary: %s" % JSON.stringify(boundaries))
		return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
