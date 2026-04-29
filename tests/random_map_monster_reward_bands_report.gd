extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_MONSTER_REWARD_BANDS_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = RandomMapGeneratorRulesScript.new()
	var config := _config("monster-reward-bands-10184")
	var report: Dictionary = generator.monster_reward_bands_report(config)
	if not bool(report.get("ok", false)):
		_fail("Monster reward bands report failed: %s" % JSON.stringify(report))
		return
	if not bool(report.get("same_input_monster_reward_bands_signature_equivalent", false)):
		_fail("Same seed/template did not preserve monster reward bands signature.")
		return
	if not bool(report.get("changed_seed_changes_monster_reward_bands_signature", false)):
		_fail("Changed seed did not change monster reward bands signature.")
		return

	var generated: Dictionary = generator.generate(config)
	if not bool(generated.get("ok", false)):
		_fail("Generated payload validation failed: %s" % JSON.stringify(generated.get("report", {})))
		return
	var payload: Dictionary = generated.get("generated_map", {})
	var bands: Dictionary = payload.get("staging", {}).get("monster_reward_bands", {})
	if not _assert_monster_reward_payload(bands):
		return
	if not _assert_references(payload, bands):
		return
	if not _assert_payload_boundaries(payload):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"stable_signature": payload.get("stable_signature", ""),
		"monster_reward_bands_signature": bands.get("monster_reward_bands_signature", ""),
		"changed_seed_monster_reward_bands_signature": report.get("changed_seed_monster_reward_bands_signature", ""),
		"summary": bands.get("summary", {}),
		"seven_category_zone_count": bands.get("seven_category_semantics", {}).get("zones", []).size(),
		"fairness_monster_reward_summary": payload.get("staging", {}).get("fairness_report", {}).get("guard_pressure", {}).get("monster_reward_bands_summary", {}),
	})])
	get_tree().quit(0)

func _config(seed: String) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "monster_reward_bands", "width": 26, "height": 18},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
			"guard_strength_profile": "core_low",
		},
	}

func _assert_monster_reward_payload(bands: Dictionary) -> bool:
	if String(bands.get("schema_id", "")) != RandomMapGeneratorRulesScript.MONSTER_REWARD_BANDS_SCHEMA_ID:
		_fail("Missing monster reward bands schema payload: %s" % JSON.stringify(bands))
		return false
	var records: Array = bands.get("monster_reward_records", [])
	if records.is_empty():
		_fail("Expected monster reward records.")
		return false
	var saw_normal := false
	var saw_special := false
	var saw_reward := false
	for record in records:
		if not (record is Dictionary):
			_fail("Monster reward record is invalid.")
			return false
		var guard_stack: Dictionary = record.get("guard_stack_record", {})
		var reward_band: Dictionary = record.get("reward_band_record", {})
		if String(record.get("guard_record_type", "")) == "normal_route_guard":
			saw_normal = true
		if String(record.get("guard_record_type", "")) == "special_guard_gate":
			saw_special = true
			if not bool(record.get("special_unlock_semantics", {}).get("unlock_required", false)):
				_fail("Special guard record did not preserve unlock semantics: %s" % JSON.stringify(record))
				return false
		if String(guard_stack.get("selected_unit_id", "")) == "" or String(guard_stack.get("strength_class", "")) == "":
			_fail("Guard stack missed deterministic unit/strength selection: %s" % JSON.stringify(record))
			return false
		if String(reward_band.get("selected_reward_category_id", "")) != "" and int(reward_band.get("value_range", {}).get("max", 0)) >= int(reward_band.get("value_range", {}).get("min", 0)):
			saw_reward = true
		if record.get("seven_category_links", {}).is_empty():
			_fail("Monster reward record missed seven-category links: %s" % JSON.stringify(record))
			return false
	if not saw_normal or not saw_special or not saw_reward:
		_fail("Expected normal guard, special guard, and reward band coverage: %s" % JSON.stringify(bands.get("summary", {})))
		return false
	var seven: Dictionary = bands.get("seven_category_semantics", {})
	if seven.get("zones", []).is_empty() or seven.get("guard_reward_category_links", []).is_empty():
		_fail("Seven-category metadata did not survive: %s" % JSON.stringify(seven))
		return false
	for zone in seven.get("zones", []):
		if zone is Dictionary and zone.get("categories", []).size() != 7:
			_fail("Zone did not expose seven original resource categories: %s" % JSON.stringify(zone))
			return false
	return true

func _assert_references(payload: Dictionary, bands: Dictionary) -> bool:
	var ids := {}
	for record in bands.get("monster_reward_records", []):
		if record is Dictionary:
			ids[String(record.get("id", ""))] = true
	var route_refs := 0
	for edge in payload.get("staging", {}).get("route_graph", {}).get("edges", []):
		if not (edge is Dictionary):
			continue
		for id_value in edge.get("monster_reward_band_ids", []):
			if not ids.has(String(id_value)):
				_fail("Route edge referenced unknown monster reward id: %s" % JSON.stringify(edge))
				return false
			route_refs += 1
	if route_refs < 2:
		_fail("Route graph did not reference enough monster reward records.")
		return false
	var object_refs := 0
	for placement in payload.get("staging", {}).get("object_placements", []):
		if placement is Dictionary:
			object_refs += placement.get("monster_reward_band_ids", []).size()
	for encounter in payload.get("scenario_record", {}).get("encounters", []):
		if encounter is Dictionary:
			object_refs += encounter.get("monster_reward_band_ids", []).size()
	if object_refs < 1:
		_fail("Object placements or encounters did not reference monster reward records.")
		return false
	if payload.get("scenario_record", {}).get("generated_constraints", {}).get("monster_reward_bands", {}).is_empty():
		_fail("Scenario generated_constraints missed monster reward bands.")
		return false
	var guard_pressure: Dictionary = payload.get("staging", {}).get("fairness_report", {}).get("guard_pressure", {})
	if guard_pressure.get("monster_reward_bands_summary", {}).is_empty():
		_fail("Fairness guard pressure missed monster reward summary.")
		return false
	return true

func _assert_payload_boundaries(payload: Dictionary) -> bool:
	if String(payload.get("write_policy", "")) != "staged_payload_only_no_authored_content_write":
		_fail("Generated payload lost staged no-write policy.")
		return false
	var scenario: Dictionary = payload.get("scenario_record", {})
	if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", true)):
		_fail("Monster reward bands adopted generated map into campaign or skirmish UI.")
		return false
	if scenario.has("save_adoption") or scenario.has("alpha_parity_claim") or payload.has("save_adoption"):
		_fail("Monster reward bands exposed save/writeback/parity claim metadata.")
		return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
