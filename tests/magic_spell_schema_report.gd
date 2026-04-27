extends Node

const REPORT_ID := "MAGIC_SPELL_SCHEMA_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var raw := ContentService.load_json(ContentService.SPELLS_PATH)
	var spells: Array = raw.get("items", [])
	var report := SpellRules.spell_schema_report(spells)
	if not bool(report.get("ok", false)):
		_fail(String(report.get("errors", [])))
		return

	if not _assert_count(report, "spell_count", 20):
		return
	if not _assert_count(report.get("context_counts", {}), SpellRules.CONTEXT_OVERWORLD, 3):
		return
	if not _assert_count(report.get("context_counts", {}), SpellRules.CONTEXT_BATTLE, 17):
		return
	for school in ["beacon", "mire", "lens", "root", "furnace", "veil"]:
		if int(report.get("school_counts", {}).get(school, 0)) <= 0:
			_fail("Missing classified spell for school %s." % school)
			return
	for category in ["damage", "buff", "debuff", "recovery", "economy_map_utility"]:
		if int(report.get("role_category_counts", {}).get(category, 0)) <= 0:
			_fail("Missing role category coverage for %s." % category)
			return

	var beacon_path := ContentService.get_spell("spell_beacon_path")
	if SpellRules.spell_school_id(beacon_path) != "beacon":
		_fail("Beacon Path did not expose beacon school metadata through SpellRules.")
		return
	if SpellRules.spell_tier(beacon_path) != 2:
		_fail("Beacon Path did not expose tier 2 metadata through SpellRules.")
		return
	if "economy_map_utility" not in SpellRules.spell_role_categories(beacon_path):
		_fail("Beacon Path did not expose economy_map_utility category through SpellRules.")
		return
	if not SpellRules.spell_metadata_summary(beacon_path).contains("Beacon T2"):
		_fail("Beacon Path metadata summary is missing school/tier evidence.")
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": report.get("schema_status", ""),
		"spell_count": report.get("spell_count", 0),
		"school_counts": report.get("school_counts", {}),
		"tier_counts": report.get("tier_counts", {}),
		"context_counts": report.get("context_counts", {}),
		"role_category_counts": report.get("role_category_counts", {}),
		"sample": {
			"spell_id": "spell_beacon_path",
			"metadata_summary": SpellRules.spell_metadata_summary(beacon_path),
			"primary_role": SpellRules.spell_primary_role(beacon_path),
			"role_categories": SpellRules.spell_role_categories(beacon_path),
		},
		"caveats": [
			"This report proves spell school/category/tier metadata loads through SpellRules; it does not add new spell balance, save data, AI casting, or adventure targeting behavior.",
			"Old Measure remains rare and scenario-gated; no normal Old Measure spell ladder is activated by this slice.",
		],
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_count(container: Variant, key: String, expected: int) -> bool:
	if int(container.get(key, -1)) != expected:
		_fail("Expected %s to be %d, got %s." % [key, expected, container.get(key, null)])
		return false
	return true

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
