extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_TOWN_MINE_DWELLING_PLACEMENT_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = RandomMapGeneratorRulesScript.new()
	var config := _config("town-mine-dwelling-placement-10184")
	var generated: Dictionary = generator.generate(config)
	if not bool(generated.get("ok", false)):
		_fail("Generated town/mine/dwelling payload failed validation: %s" % JSON.stringify(generated.get("report", {})))
		return
	var payload: Dictionary = generated.get("generated_map", {})
	var report: Dictionary = generator.town_mine_dwelling_placement_report(config)
	if not bool(report.get("ok", false)):
		_fail("Town/mine/dwelling report failed: %s" % JSON.stringify(report))
		return
	if String(report.get("schema_id", "")) != RandomMapGeneratorRulesScript.TOWN_MINE_DWELLING_PLACEMENT_REPORT_SCHEMA_ID:
		_fail("Report schema id mismatch: %s" % JSON.stringify(report))
		return
	if not bool(report.get("same_input_town_mine_dwelling_signature_equivalent", false)):
		_fail("Same seed/config changed town/mine/dwelling signature.")
		return
	if not bool(report.get("changed_seed_changes_town_mine_dwelling_signature", false)):
		_fail("Changed seed did not change town/mine/dwelling signature.")
		return

	var placement: Dictionary = payload.get("staging", {}).get("town_mine_dwelling_placement", {})
	if not _assert_placement_payload(placement):
		return
	if not _assert_record_metadata(placement):
		return
	if not _assert_conflict_boundaries(payload, placement):
		return
	if not _assert_fairness(payload.get("staging", {}).get("fairness_report", {})):
		return
	if not _assert_generated_boundaries(payload):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"stable_signature": payload.get("stable_signature", ""),
		"town_mine_dwelling_signature": placement.get("town_mine_dwelling_signature", ""),
		"changed_seed_town_mine_dwelling_signature": report.get("changed_seed_town_mine_dwelling_signature", ""),
		"summary": placement.get("summary", {}),
		"fairness_summary": payload.get("staging", {}).get("fairness_report", {}).get("summary", {}),
	})])
	get_tree().quit(0)

func _config(seed: String) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "town_mine_dwelling", "width": 30, "height": 22, "water_mode": "land", "level_count": 1},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "frontier_spokes_profile_v1",
			"template_id": "frontier_spokes_v1",
			"guard_strength_profile": "core_low",
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
		},
	}

func _assert_placement_payload(placement: Dictionary) -> bool:
	if String(placement.get("schema_id", "")) != RandomMapGeneratorRulesScript.TOWN_MINE_DWELLING_PLACEMENT_SCHEMA_ID:
		_fail("Missing town/mine/dwelling schema payload: %s" % JSON.stringify(placement))
		return false
	if String(placement.get("status", "")) != "pass":
		_fail("Town/mine/dwelling payload did not pass: %s" % JSON.stringify(placement.get("validation", {})))
		return false
	if String(placement.get("town_mine_dwelling_signature", "")) == "":
		_fail("Town/mine/dwelling signature missing.")
		return false
	var summary: Dictionary = placement.get("summary", {})
	if int(summary.get("town_count", 0)) <= 0 or int(summary.get("mine_count", 0)) <= 0 or int(summary.get("dwelling_count", 0)) <= 0:
		_fail("Town/mine/dwelling records were not all present: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("same_type_neutral_town_count", 0)) <= 0:
		_fail("Same-type neutral town semantics were not exercised: %s" % JSON.stringify(summary))
		return false
	var validation: Dictionary = placement.get("validation", {})
	if not bool(validation.get("ok", false)) or not validation.get("conflicts", []).is_empty():
		_fail("Town/mine/dwelling validation failed or found conflicts: %s" % JSON.stringify(validation))
		return false
	return true

func _assert_record_metadata(placement: Dictionary) -> bool:
	var town_records: Array = placement.get("town_start_records", [])
	var mine_records: Array = placement.get("mine_resource_producer_records", [])
	var dwelling_records: Array = placement.get("dwelling_recruitment_site_records", [])
	var same_type_seen := false
	for record in town_records:
		if not (record is Dictionary):
			_fail("Town record was not a dictionary.")
			return false
		for key in ["owner", "faction_id", "town_id", "zone_role", "footprint_action_metadata", "town_assignment_semantics", "same_type_semantics"]:
			if not record.has(key):
				_fail("Town record missed %s: %s" % [key, JSON.stringify(record)])
				return false
		if String(record.get("owner", "")) == "neutral" and String(record.get("same_type_semantics", "")).find("source_zone_choice_reused") >= 0:
			same_type_seen = true
		if not _assert_record_pathing(record, "town"):
			return false
	if not same_type_seen:
		_fail("No neutral town carried same-type/source-zone semantics.")
		return false

	for record in mine_records:
		if not (record is Dictionary):
			_fail("Mine record was not a dictionary.")
			return false
		for key in ["owner", "original_resource_category_id", "seven_category_index", "guard_pressure", "frontier_metadata", "adjacent_resource_metadata", "footprint_action_metadata"]:
			if not record.has(key):
				_fail("Mine record missed %s: %s" % [key, JSON.stringify(record)])
				return false
		if String(record.get("original_resource_category_id", "")) not in ["timber", "quicksilver", "ore", "ember_salt", "lens_crystal", "cut_gems", "gold"]:
			_fail("Mine record used unknown original resource category: %s" % JSON.stringify(record))
			return false
		if not bool(record.get("adjacent_resource_metadata", {}).get("staged", false)):
			_fail("Mine record missed staged adjacent resource metadata: %s" % JSON.stringify(record))
			return false
		if not _assert_record_pathing(record, "mine"):
			return false

	for record in dwelling_records:
		if not (record is Dictionary):
			_fail("Dwelling record was not a dictionary.")
			return false
		for key in ["owner", "neutral_dwelling_family_id", "zone_role", "guard_pressure", "reward_context", "monster_band_context", "footprint_action_metadata"]:
			if not record.has(key):
				_fail("Dwelling record missed %s: %s" % [key, JSON.stringify(record)])
				return false
		if not _assert_record_pathing(record, "dwelling"):
			return false
	return true

func _assert_record_pathing(record: Dictionary, label: String) -> bool:
	if String(record.get("pathing_status", "")) != "pass":
		_fail("%s record did not pass pathing: %s" % [label, JSON.stringify(record)])
		return false
	var meta: Dictionary = record.get("footprint_action_metadata", {})
	if record.get("body_tiles", []).is_empty() or meta.get("runtime_body_mask", []).is_empty():
		_fail("%s record missed body/runtime footprint metadata: %s" % [label, JSON.stringify(record)])
		return false
	if meta.get("placement_predicate_results", {}).is_empty():
		_fail("%s record missed placement predicate results: %s" % [label, JSON.stringify(record)])
		return false
	if not bool(meta.get("placement_predicate_results", {}).get("in_bounds", false)) or not bool(meta.get("placement_predicate_results", {}).get("terrain_allowed", false)):
		_fail("%s record failed required placement predicates: %s" % [label, JSON.stringify(record)])
		return false
	if meta.get("passability_mask", {}).is_empty() or meta.get("action_mask", {}).is_empty():
		_fail("%s record missed passability/action masks: %s" % [label, JSON.stringify(record)])
		return false
	return true

func _assert_conflict_boundaries(payload: Dictionary, placement: Dictionary) -> bool:
	var reserved := {}
	for object_record in payload.get("staging", {}).get("object_placements", []):
		if not (object_record is Dictionary):
			continue
		var kind := String(object_record.get("kind", ""))
		if kind not in ["route_guard", "special_guard_gate", "decorative_obstacle"]:
			continue
		for tile in object_record.get("body_tiles", []):
			if tile is Dictionary:
				reserved[_point_key(tile)] = kind
	for tile in payload.get("staging", {}).get("road_network", {}).get("road_overlay", {}).get("tiles", []):
		if tile is Dictionary:
			reserved[_point_key(tile)] = "road"

	var seen_bodies := {}
	var records := []
	records.append_array(placement.get("town_start_records", []))
	records.append_array(placement.get("mine_resource_producer_records", []))
	records.append_array(placement.get("dwelling_recruitment_site_records", []))
	for record in records:
		if not (record is Dictionary):
			continue
		for tile in record.get("body_tiles", []):
			if not (tile is Dictionary):
				_fail("Placement body tile was invalid: %s" % JSON.stringify(record))
				return false
			var key := _point_key(tile)
			if seen_bodies.has(key):
				_fail("Town/mine/dwelling body collision at %s between %s and %s." % [key, String(seen_bodies[key]), String(record.get("placement_id", ""))])
				return false
			seen_bodies[key] = String(record.get("placement_id", ""))
			if reserved.has(key):
				_fail("Town/mine/dwelling body overlapped reserved %s at %s: %s" % [String(reserved[key]), key, JSON.stringify(record)])
				return false
	return true

func _assert_fairness(fairness: Dictionary) -> bool:
	if String(fairness.get("status", "")) != "pass":
		_fail("Fairness report did not pass: %s" % JSON.stringify(fairness))
		return false
	var producer: Dictionary = fairness.get("core_economy_producer_access", {})
	if String(producer.get("status", "")) != "pass" or producer.get("per_player", []).is_empty():
		_fail("Core economy producer fairness missing or failed: %s" % JSON.stringify(producer))
		return false
	for entry in producer.get("per_player", []):
		if not (entry is Dictionary):
			_fail("Core economy producer entry was invalid.")
			return false
		if not bool(entry.get("starting_town_supported", false)) or String(entry.get("status", "")) != "pass":
			_fail("Starting town core producer support failed: %s" % JSON.stringify(entry))
			return false
	var contested: Dictionary = fairness.get("contested_objective_pressure_markers", {})
	if String(contested.get("status", "")) != "pass" or contested.get("markers", []).is_empty():
		_fail("Contested objective pressure markers missing or failed: %s" % JSON.stringify(contested))
		return false
	return true

func _assert_generated_boundaries(payload: Dictionary) -> bool:
	if String(payload.get("write_policy", "")) != "generated_export_record_no_authored_content_write":
		_fail("Generated payload write policy changed: %s" % String(payload.get("write_policy", "")))
		return false
	if bool(payload.get("scenario_record", {}).get("selection", {}).get("availability", {}).get("campaign", true)):
		_fail("Generated scenario became campaign-available.")
		return false
	if payload.has("authored_content_writeback") or payload.get("scenario_record", {}).has("alpha_parity_claim"):
		_fail("Generated payload exposed authored writeback or parity claim.")
		return false
	if payload.get("scenario_record", {}).get("generated_constraints", {}).get("town_mine_dwelling_placement", {}).is_empty():
		_fail("Scenario generated constraints missed town/mine/dwelling placement provenance.")
		return false
	return true

func _point_key(tile: Dictionary) -> String:
	return "%d,%d" % [int(tile.get("x", 0)), int(tile.get("y", 0))]

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
