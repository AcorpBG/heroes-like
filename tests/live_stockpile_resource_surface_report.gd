extends Node

const SCENARIO_ID := "river-pass"
const SAVE_SLOT := 3
const STOCKPILE_KEYS := [
	"gold",
	"wood",
	"ore",
	"aetherglass",
	"embergrain",
	"peatwax",
	"verdant_grafts",
	"brass_scrip",
	"memory_salt",
]
const RESOURCE_LABELS := {
	"gold": "Gold",
	"wood": "Wood",
	"ore": "Ore",
	"aetherglass": "Aetherglass",
	"embergrain": "Embergrain",
	"peatwax": "Peatwax",
	"verdant_grafts": "Verdant grafts",
	"brass_scrip": "Brass scrip",
	"memory_salt": "Memory salt",
}
const RARE_SITE_IDS := {
	"aetherglass": "site_aetherglass_lens_house",
	"embergrain": "site_embergrain_warm_granary",
	"peatwax": "site_peatwax_reed_yard",
	"verdant_grafts": "site_verdant_graft_nursery",
	"brass_scrip": "site_brass_scrip_mint",
	"memory_salt": "site_memory_salt_pan",
}

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	session.overworld["resources"] = _seeded_resources()
	OverworldRules.normalize_overworld_state(session)
	_assert_exact_stockpile_keys("normalized seeded resources", session.overworld.get("resources", {}))
	var zero_surface_text := OverworldRules.describe_resource_stockpile(_common_only_resources(), true)
	_assert_surface_labels("zero rare stockpile surface", zero_surface_text, true)
	var visible_surface_text := OverworldRules.describe_resources(session)
	_assert_surface_labels("visible seeded stockpile surface", visible_surface_text, true)
	if _failed:
		return

	_install_controlled_rare_sites(session)
	var site_income := OverworldRules.controlled_resource_site_income(session, "player")
	_assert_exact_stockpile_keys("controlled site income", site_income)
	for resource_id in RARE_SITE_IDS.keys():
		_assert_resource_amount("controlled site income", site_income, String(resource_id), 1)
	if _failed:
		return

	var before_turn := _stockpile(session)
	var turn_result: Dictionary = OverworldRules.end_turn(session)
	_assert_ok("end turn with rare site income", turn_result)
	var after_turn := _stockpile(session)
	for resource_id in RARE_SITE_IDS.keys():
		_assert_resource_amount_at_least(
			"post-turn rare stockpile",
			after_turn,
			String(resource_id),
			int(before_turn.get(String(resource_id), 0)) + 1
		)
	var income_summary := String(turn_result.get("resource_income_summary", ""))
	for resource_id in RARE_SITE_IDS.keys():
		_assert_contains(income_summary, String(resource_id), "resource income summary")
	if _failed:
		return

	var save_resume := _save_and_resume_signature(session)
	if _failed:
		return

	var payload := {
		"ok": true,
		"schema": "live_stockpile_resource_surface_report_v1",
		"scenario_id": SCENARIO_ID,
		"live_stockpile_resource_ids": STOCKPILE_KEYS,
		"resource_surface_text": visible_surface_text,
		"zero_rare_surface_text": zero_surface_text,
		"controlled_site_income": site_income,
		"resource_income_summary": income_summary,
		"before_turn": before_turn,
		"after_turn": after_turn,
		"save_resume": save_resume,
		"rare_site_ids": RARE_SITE_IDS,
		"caveats": [
			"Fixture injects controlled rare-resource sites into River Pass to exercise the shared live income and save paths deterministically.",
			"The report verifies resource surface and persistence wiring, not final scenario-wide economy balance.",
		],
	}
	print("LIVE_STOCKPILE_RESOURCE_SURFACE_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(0)

func _seeded_resources() -> Dictionary:
	var resources := {}
	var amount := 10
	for resource_id in STOCKPILE_KEYS:
		resources[String(resource_id)] = amount
		amount += 1
	return resources

func _common_only_resources() -> Dictionary:
	return {
		"gold": 1500,
		"wood": 4,
		"ore": 3,
	}

func _install_controlled_rare_sites(session) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
	var offset := 0
	for resource_id in RARE_SITE_IDS.keys():
		var site_id := String(RARE_SITE_IDS.get(resource_id, ""))
		var site := ContentService.get_resource_site(site_id)
		if site.is_empty():
			_fail("Missing rare resource site %s for %s" % [site_id, resource_id])
			return
		nodes.append({
			"placement_id": "live_stockpile_surface_%s" % resource_id,
			"site_id": site_id,
			"x": 40 + offset,
			"y": 4,
			"collected": true,
			"collected_by_faction_id": "player",
		})
		offset += 1
	session.overworld["resource_nodes"] = nodes

func _save_and_resume_signature(session) -> Dictionary:
	var before := _session_signature(session)
	var save_result: Dictionary = SaveService.save_runtime_manual_session(session, SAVE_SLOT)
	_assert_ok("manual save", save_result)
	if _failed:
		return {}
	var restored = SaveService.restore_manual_session(SAVE_SLOT)
	if restored == null:
		_fail("manual save restore returned null")
		return {}
	OverworldRules.normalize_overworld_state(restored)
	var after := _session_signature(restored)
	if JSON.stringify(before) != JSON.stringify(after):
		_fail("save/resume signature mismatch: before=%s after=%s" % [before, after])
		return {}
	return {
		"ok": true,
		"slot": SAVE_SLOT,
		"signature_before": before,
		"signature_after": after,
	}

func _session_signature(session) -> Dictionary:
	return {
		"save_version": int(session.save_version),
		"scenario_id": String(session.scenario_id),
		"day": int(session.day),
		"resources": _stockpile(session),
		"controlled_site_income": OverworldRules.controlled_resource_site_income(session, "player"),
		"resource_surface_text": OverworldRules.describe_resources(session),
		"full_resource_surface_text": OverworldRules.describe_resource_stockpile(session.overworld.get("resources", {}), true),
	}

func _stockpile(session) -> Dictionary:
	var resources := {}
	for resource_id in STOCKPILE_KEYS:
		resources[String(resource_id)] = int(session.overworld.get("resources", {}).get(String(resource_id), 0))
	return resources

func _assert_exact_stockpile_keys(label: String, resources: Variant) -> void:
	if not (resources is Dictionary):
		_fail("%s was not a dictionary" % label)
		return
	var actual := []
	for key in resources.keys():
		actual.append(String(key))
	actual.sort()
	var expected := STOCKPILE_KEYS.duplicate()
	expected.sort()
	if JSON.stringify(actual) != JSON.stringify(expected):
		_fail("%s expected stockpile keys %s, got %s" % [label, expected, actual])

func _assert_surface_labels(label: String, surface_text: String, require_rare: bool) -> void:
	for resource_id in STOCKPILE_KEYS:
		if not require_rare and String(resource_id) not in ["gold", "wood", "ore"]:
			continue
		_assert_contains(surface_text, String(RESOURCE_LABELS.get(resource_id, resource_id)), label)

func _assert_resource_amount(label: String, resources: Variant, resource_id: String, expected: int) -> void:
	if not (resources is Dictionary):
		_fail("%s resources were not a dictionary" % label)
		return
	if int(resources.get(resource_id, 0)) != expected:
		_fail("%s expected %s=%d, got %s" % [label, resource_id, expected, resources])

func _assert_resource_amount_at_least(label: String, resources: Variant, resource_id: String, minimum: int) -> void:
	if not (resources is Dictionary):
		_fail("%s resources were not a dictionary" % label)
		return
	if int(resources.get(resource_id, 0)) < minimum:
		_fail("%s expected %s >= %d, got %s" % [label, resource_id, minimum, resources])

func _assert_contains(text: String, expected: String, label: String) -> void:
	if not text.contains(expected):
		_fail("%s expected token %s, got %s" % [label, expected, text])

func _assert_ok(label: String, result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_fail("%s failed: %s" % [label, result])

func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	var payload := {
		"ok": false,
		"schema": "live_stockpile_resource_surface_report_v1",
		"scenario_id": SCENARIO_ID,
		"error": message,
	}
	push_error(message)
	print("LIVE_STOCKPILE_RESOURCE_SURFACE_REPORT %s" % JSON.stringify(payload))
	get_tree().quit(1)
