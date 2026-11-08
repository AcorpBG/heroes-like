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

	if not _assert_min_count(report, "spell_count", 100):
		return
	for context in [SpellRules.CONTEXT_OVERWORLD, SpellRules.CONTEXT_BATTLE]:
		if not _assert_min_count(report.get("context_counts", {}), context, 1):
			return
	# The basic tier and the four schools (docs/magic-system.md, The shape).
	for school in SpellRules.SPELL_SCHOOL_IDS + [SpellRules.BASIC_SCHOOL_ID]:
		if int(report.get("school_counts", {}).get(school, 0)) <= 0:
			_fail("School %s has no spells." % school)
			return
	for school in report.get("school_counts", {}).keys():
		if String(school) not in SpellRules.SPELL_SCHOOL_IDS and String(school) != SpellRules.BASIC_SCHOOL_ID:
			_fail("Spell catalog names a school outside the four and the basic tier: %s." % school)
			return
	for tier in ["1", "2", "3", "4", "5"]:
		if int(report.get("tier_counts", {}).get(tier, 0)) <= 0:
			_fail("Spell catalog has no tier %s spells." % tier)
			return
	for category in ["damage", "buff", "debuff", "recovery", "economy_map_utility"]:
		if int(report.get("role_category_counts", {}).get(category, 0)) <= 0:
			_fail("Missing role category coverage for %s." % category)
			return

	var relay := ContentService.get_spell("spell_relay")
	if SpellRules.spell_school_id(relay) != "beacon":
		_fail("Relay did not expose beacon school metadata through SpellRules.")
		return
	if SpellRules.spell_tier(relay) != 3:
		_fail("Relay did not expose tier 3 metadata through SpellRules.")
		return
	if "economy_map_utility" not in SpellRules.spell_role_categories(relay):
		_fail("Relay did not expose economy_map_utility category through SpellRules.")
		return
	if not SpellRules.spell_metadata_summary(relay).contains("Beacon T3"):
		_fail("Relay metadata summary is missing school/tier evidence.")
		return
	var far_sight := ContentService.get_spell("spell_far_sight")
	if SpellRules.spell_school_id(far_sight) != SpellRules.BASIC_SCHOOL_ID:
		_fail("Far Sight did not expose the basic tier through SpellRules.")
		return
	if SpellRules.spell_primary_role(far_sight) != "scouting_support":
		_fail("Far Sight did not expose scouting_support metadata through SpellRules.")
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
			"spell_id": "spell_far_sight",
			"metadata_summary": SpellRules.spell_metadata_summary(far_sight),
			"primary_role": SpellRules.spell_primary_role(far_sight),
			"role_categories": SpellRules.spell_role_categories(far_sight),
		},
		"caveats": [
			"This report proves spell school/category/tier metadata loads through SpellRules.",
		],
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_count(container: Variant, key: String, expected: int) -> bool:
	if int(container.get(key, -1)) != expected:
		_fail("Expected %s to be %d, got %s." % [key, expected, container.get(key, null)])
		return false
	return true

func _assert_min_count(container: Variant, key: String, minimum: int) -> bool:
	if int(container.get(key, -1)) < minimum:
		_fail("Expected %s to be at least %d, got %s." % [key, minimum, container.get(key, null)])
		return false
	return true

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
