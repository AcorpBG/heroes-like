extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_OBJECT_FOOTPRINT_CATALOG_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = RandomMapGeneratorRulesScript.new()
	var config := _config("decoration-density-pass-10184")
	var generated: Dictionary = generator.generate(config)
	if not bool(generated.get("ok", false)):
		_fail("Generated payload validation failed: %s" % JSON.stringify(generated.get("report", {})))
		return
	var payload: Dictionary = generated.get("generated_map", {})
	var report: Dictionary = generator.object_footprint_report(config)
	if not bool(report.get("ok", false)):
		_fail("Object footprint report failed: %s" % JSON.stringify(report))
		return
	if not bool(report.get("same_input_object_footprint_signature_equivalent", false)):
		_fail("Same seed/template did not preserve object footprint signature.")
		return
	if not bool(report.get("changed_seed_changes_object_footprint_signature", false)):
		_fail("Changed seed did not change object footprint signature.")
		return

	var footprints: Dictionary = payload.get("staging", {}).get("object_footprint_catalog", {})
	if not _assert_footprint_payload(payload, footprints):
		return
	if not _assert_record_coverage(payload, footprints):
		return
	if not _assert_payload_boundaries(payload):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"stable_signature": payload.get("stable_signature", ""),
		"object_footprint_signature": footprints.get("object_footprint_signature", ""),
		"changed_seed_object_footprint_signature": report.get("changed_seed_object_footprint_signature", ""),
		"summary": footprints.get("summary", {}),
		"coverage": footprints.get("coverage", {}),
		"validation": footprints.get("validation", {}),
	})])
	get_tree().quit(0)

func _config(seed: String) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "decoration_density", "width": 26, "height": 18},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
			"guard_strength_profile": "core_low",
		},
	}

func _assert_footprint_payload(payload: Dictionary, footprints: Dictionary) -> bool:
	if String(footprints.get("schema_id", "")) != RandomMapGeneratorRulesScript.OBJECT_FOOTPRINT_CATALOG_SCHEMA_ID:
		_fail("Missing object footprint schema payload: %s" % JSON.stringify(footprints))
		return false
	if String(footprints.get("status", "")) != "pass":
		_fail("Object footprint payload did not pass: %s" % JSON.stringify(footprints.get("validation", {})))
		return false
	var catalog: Dictionary = footprints.get("catalog", {})
	if catalog.get("records", []).is_empty():
		_fail("Object footprint catalog has no records.")
		return false
	var required_kinds := {"town": false, "resource_site": false, "route_guard": false, "special_guard_gate": false, "decorative_obstacle": false, "reward_reference": false, "mine_placeholder": false}
	for catalog_record in catalog.get("records", []):
		if not (catalog_record is Dictionary):
			_fail("Catalog record is invalid.")
			return false
		for key in ["footprint", "body_mask", "runtime_body_mask", "visit_mask", "approach_mask", "passability_mask", "action_mask", "terrain_restrictions", "placement_predicates"]:
			if not catalog_record.has(key):
				_fail("Catalog record missed %s: %s" % [key, JSON.stringify(catalog_record)])
				return false
		if catalog_record.get("body_mask", []).is_empty() or catalog_record.get("runtime_body_mask", []).is_empty():
			_fail("Catalog record missed body/runtime body masks: %s" % JSON.stringify(catalog_record))
			return false
		if catalog_record.get("passability_mask", {}).is_empty() or catalog_record.get("action_mask", {}).is_empty():
			_fail("Catalog record missed passability/action masks: %s" % JSON.stringify(catalog_record))
			return false
		for kind in catalog_record.get("placement_kinds", []):
			if required_kinds.has(String(kind)):
				required_kinds[String(kind)] = true
	for kind in required_kinds.keys():
		if not bool(required_kinds[kind]):
			_fail("Catalog missed required generated placement kind %s." % String(kind))
			return false
	if payload.get("scenario_record", {}).get("generated_constraints", {}).get("object_footprint_catalog", {}).is_empty():
		_fail("Scenario generated_constraints missed object footprint catalog.")
		return false
	return true

func _assert_record_coverage(payload: Dictionary, footprints: Dictionary) -> bool:
	var object_records: Array = footprints.get("object_records", [])
	var reward_refs: Array = footprints.get("reward_reference_records", [])
	var placements: Array = payload.get("staging", {}).get("object_placements", [])
	var decorations: Array = payload.get("staging", {}).get("decorative_object_staging", [])
	if object_records.size() < placements.size() + decorations.size():
		_fail("Object footprint record coverage is incomplete.")
		return false
	if reward_refs.is_empty():
		_fail("Object footprint payload missed monster reward references.")
		return false
	for record in object_records:
		if not (record is Dictionary):
			_fail("Object footprint record is invalid.")
			return false
		var ref: Dictionary = record.get("object_footprint_catalog_ref", {})
		if String(ref.get("status", "")) != "catalog_record_applied":
			_fail("Generated object lacked catalog record or structured ref: %s" % JSON.stringify(record))
			return false
		if not record.has("visit_mask") or not record.has("approach_mask"):
			_fail("Generated object missed visit/approach mask metadata: %s" % JSON.stringify(record))
			return false
		if record.get("body_tiles", []).is_empty() or record.get("passability_mask", {}).is_empty() or record.get("action_mask", {}).is_empty():
			_fail("Generated object missed body/passability/action metadata: %s" % JSON.stringify(record))
			return false
		if record.get("terrain_restrictions", {}).is_empty() or record.get("placement_predicate_results", {}).is_empty():
			_fail("Generated object missed terrain or predicate metadata: %s" % JSON.stringify(record))
			return false
	for reward_ref in reward_refs:
		if not (reward_ref is Dictionary):
			_fail("Reward reference is invalid.")
			return false
		if String(reward_ref.get("object_footprint_catalog_ref", {}).get("status", "")) != "catalog_record_applied":
			_fail("Reward reference lacked footprint catalog record: %s" % JSON.stringify(reward_ref))
			return false
		if String(reward_ref.get("deferred_reason", "")) == "":
			_fail("Reward reference did not expose deferred body placement reason: %s" % JSON.stringify(reward_ref))
			return false
	var validation: Dictionary = footprints.get("validation", {})
	if not bool(validation.get("ok", false)):
		_fail("Object footprint validation failed: %s" % JSON.stringify(validation))
		return false
	if validation.get("missing_catalog_ids", []).size() > 0 or validation.get("body_overlap_failures", []).size() > 0 or validation.get("terrain_restriction_failures", []).size() > 0:
		_fail("Object footprint validation found missing catalog, overlap, or terrain failures: %s" % JSON.stringify(validation))
		return false
	if String(validation.get("required_route_check_status", "")) != "pass":
		_fail("Required routes did not remain passable under footprint validation.")
		return false
	return true

func _assert_payload_boundaries(payload: Dictionary) -> bool:
	if String(payload.get("write_policy", "")) != "generated_export_record_no_authored_content_write":
		_fail("Generated payload lost staged no-write policy.")
		return false
	var scenario: Dictionary = payload.get("scenario_record", {})
	if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", true)):
		_fail("Object footprint catalog adopted generated map into campaign or skirmish UI.")
		return false
	if scenario.has("save_adoption") or scenario.has("alpha_parity_claim") or payload.has("save_adoption"):
		_fail("Object footprint catalog exposed save/writeback/parity claim metadata.")
		return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
