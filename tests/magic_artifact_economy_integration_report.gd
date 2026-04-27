extends Node

const REPORT_ID := "MAGIC_ARTIFACT_ECONOMY_INTEGRATION_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var raw := ContentService.load_json(ContentService.SPELLS_PATH)
	var spells: Array = raw.get("items", [])
	var hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "Road Relic Caster",
			"command": {"power": 1, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": [
					"spell_waystride",
					"spell_trailglyph",
					"spell_beacon_path",
				],
				"mana": {"current": 10, "max": 40},
			},
			"artifacts": {
				"equipped": {
					"boots": "artifact_trailsinger_boots",
					"trinket": "artifact_quarry_tally_rod",
				},
				"inventory": [],
			},
		}
	)
	var movement := {"current": 1, "max": 10}
	var trailglyph := ContentService.get_spell("spell_trailglyph")
	var base_hero := SpellRules.ensure_hero_spellbook(
		{
			"name": "No Relic Caster",
			"command": {"power": 1, "knowledge": 8},
			"spellbook": {
				"known_spell_ids": ["spell_trailglyph"],
				"mana": {"current": 10, "max": 40},
			},
		}
	)
	var base_preview := SpellRules.adventure_spell_consequence_preview(base_hero, movement, trailglyph)
	var relic_preview := SpellRules.adventure_spell_consequence_preview(hero, movement, trailglyph)
	if int(base_preview.get("mana_cost", 0)) != 4 or int(relic_preview.get("mana_cost", 0)) != 3:
		_fail("Artifact mana bridge did not lower Trailglyph mana cost by 1: base=%s relic=%s" % [base_preview, relic_preview])
		return
	if int(base_preview.get("movement_after", 0)) != 7 or int(relic_preview.get("movement_after", 0)) != 8:
		_fail("Artifact effect bridge did not improve Trailglyph movement preview by 1: base=%s relic=%s" % [base_preview, relic_preview])
		return
	var cast_result := SpellRules.cast_overworld_spell(hero, movement, "spell_trailglyph")
	if not bool(cast_result.get("ok", false)):
		_fail("Artifact-adjusted Trailglyph cast failed: %s" % cast_result)
		return
	if int(cast_result.get("movement", {}).get("current", 0)) != 8:
		_fail("Artifact-adjusted Trailglyph cast did not apply the movement preview: %s" % cast_result)
		return
	if int(cast_result.get("hero", {}).get("spellbook", {}).get("mana", {}).get("current", 0)) != 7:
		_fail("Artifact-adjusted Trailglyph cast did not spend the adjusted mana cost: %s" % cast_result)
		return

	var report := SpellRules.magic_artifact_economy_integration_report(hero, movement, spells)
	if not bool(report.get("ok", false)):
		_fail("Integration report failed: %s" % report)
		return
	if int(report.get("artifact_spell_hook_count", 0)) <= 0:
		_fail("Integration report did not expose artifact spell hook records: %s" % report)
		return
	var income: Dictionary = report.get("common_artifact_income", {}) if report.get("common_artifact_income", {}) is Dictionary else {}
	if int(income.get("gold", 0)) != 120 or int(income.get("ore", 0)) != 1:
		_fail("Integration report did not preserve common artifact economy income: %s" % report)
		return
	if not (report.get("rare_artifact_income", {}) is Dictionary) or not report.get("rare_artifact_income", {}).is_empty():
		_fail("Integration report activated rare artifact income unexpectedly: %s" % report)
		return
	var resource_policy: Dictionary = report.get("resource_policy", {}) if report.get("resource_policy", {}) is Dictionary else {}
	if String(resource_policy.get("live_cost_mode", "")) != "mana_only" or bool(resource_policy.get("rare_resource_costs_active", true)):
		_fail("Integration report did not preserve mana-only rare-resource boundary: %s" % report)
		return
	if not _assert_public_payload("integration report", report):
		return
	if not _assert_public_payload("cast result", cast_result):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": String(report.get("schema_status", "")),
		"artifact_spell_hook_count": int(report.get("artifact_spell_hook_count", 0)),
		"common_artifact_income": income,
		"trailglyph": {
			"base_mana_cost": int(base_preview.get("mana_cost", 0)),
			"artifact_mana_cost": int(relic_preview.get("mana_cost", 0)),
			"base_movement_after": int(base_preview.get("movement_after", 0)),
			"artifact_movement_after": int(relic_preview.get("movement_after", 0)),
			"cast_mana_after": int(cast_result.get("hero", {}).get("spellbook", {}).get("mana", {}).get("current", 0)),
		},
		"resource_policy": resource_policy,
		"caveats": [
			"This report proves bounded artifact spell-affinity and common-resource economy reporting only; rare-resource costs, market migration, save migration, artifact taxonomy overhaul, and economy rebalance remain outside this slice.",
		],
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_public_payload(label: String, payload: Variant) -> bool:
	var surface_text := JSON.stringify(payload).to_lower()
	for leak_token in ["debug", "score", "internal"]:
		if surface_text.contains(leak_token):
			_fail("%s leaked %s: %s" % [label, leak_token, surface_text])
			return false
	return true

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
