extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_ZONE_LAYOUT_WATER_UNDERGROUND_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator = RandomMapGeneratorRulesScript.new()
	var base_config := _layout_config("zone-layout-10184", "land", 1)
	var report: Dictionary = generator.zone_layout_report(base_config)
	if not bool(report.get("ok", false)):
		_fail("Zone layout report failed: %s" % JSON.stringify(report))
		return
	var base_payload: Dictionary = generator.generate(base_config).get("generated_map", {})
	if not _assert_layout_payload(base_payload, "land", 1):
		return

	var changed_seed_payload: Dictionary = generator.generate(_layout_config("zone-layout-10184-changed", "land", 1)).get("generated_map", {})
	if _layout_signature(base_payload) == _layout_signature(changed_seed_payload):
		_fail("Changed seed did not change the zone layout signature.")
		return

	var water_payload: Dictionary = generator.generate(_layout_config("zone-layout-10184", "islands", 1)).get("generated_map", {})
	if not _assert_layout_payload(water_payload, "islands", 1):
		return
	if _layout_signature(base_payload) == _layout_signature(water_payload):
		_fail("Changing to supported island water mode did not change layout signature.")
		return

	var underground_payload: Dictionary = generator.generate(_layout_config("zone-layout-10184", "land", 2)).get("generated_map", {})
	if not _assert_layout_payload(underground_payload, "land", 2):
		return
	if _layout_signature(base_payload) == _layout_signature(underground_payload):
		_fail("Changing to supported underground level mode did not change layout signature.")
		return

	if not _assert_unsupported_level_request_rejects(generator):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"stable_signature": base_payload.get("stable_signature", ""),
		"changed_seed_signature": changed_seed_payload.get("stable_signature", ""),
		"layout_signature": _layout_signature(base_payload),
		"changed_seed_layout_signature": _layout_signature(changed_seed_payload),
		"water_layout_signature": _layout_signature(water_payload),
		"underground_layout_signature": _layout_signature(underground_payload),
		"water_cells": water_payload.get("staging", {}).get("zone_layout", {}).get("policy", {}).get("water_policy", {}).get("surface_water_cell_count", 0),
		"underground_levels": underground_payload.get("staging", {}).get("zone_layout", {}).get("levels", []).size(),
		"corridor_candidates": base_payload.get("staging", {}).get("zone_layout", {}).get("corridor_candidates", []).size(),
		"no_ui_save_adoption": base_payload.get("scenario_record", {}).get("selection", {}).get("availability", {}),
	})])
	get_tree().quit(0)

func _layout_config(seed: String, water_mode: String, level_count: int) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": seed,
		"size": {"preset": "zone_layout", "width": 36, "height": 30, "water_mode": water_mode, "level_count": level_count},
		"player_constraints": {"human_count": 2, "player_count": 4, "team_mode": "free_for_all"},
		"profile": {
			"id": "translated_rmg_profile_001_v1",
			"template_id": "translated_rmg_template_001_v1",
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
	}

func _assert_layout_payload(payload: Dictionary, expected_water_mode: String, expected_level_count: int) -> bool:
	if payload.is_empty():
		_fail("Expected generated payload for supported layout request.")
		return false
	var layout: Dictionary = payload.get("staging", {}).get("zone_layout", {})
	if String(layout.get("schema_id", "")) != RandomMapGeneratorRulesScript.ZONE_LAYOUT_SCHEMA_ID:
		_fail("Missing zone layout schema payload: %s" % JSON.stringify(layout))
		return false
	if String(layout.get("layout_signature", "")) == "":
		_fail("Missing deterministic zone layout signature.")
		return false
	if String(layout.get("policy", {}).get("water_mode", "")) != expected_water_mode:
		_fail("Layout water mode mismatch: %s" % JSON.stringify(layout.get("policy", {})))
		return false
	if int(layout.get("dimensions", {}).get("level_count", 0)) != expected_level_count or layout.get("levels", []).size() != expected_level_count:
		_fail("Layout level metadata mismatch: %s" % JSON.stringify(layout.get("dimensions", {})))
		return false
	if not _assert_area_allocation(layout):
		return false
	if not _assert_corridor_candidates(layout):
		return false
	if expected_water_mode == "islands":
		var water_policy: Dictionary = layout.get("policy", {}).get("water_policy", {})
		if not bool(water_policy.get("requested", false)) or int(water_policy.get("surface_water_cell_count", 0)) <= 0:
			_fail("Island request did not create explicit water metadata/cells: %s" % JSON.stringify(water_policy))
			return false
		if "water_transit_object_placement_deferred" not in layout.get("unsupported_runtime_features", []):
			_fail("Island request did not preserve explicit deferred water transit metadata.")
			return false
	if expected_level_count > 1:
		var underground_policy: Dictionary = layout.get("policy", {}).get("underground_policy", {})
		if not bool(underground_policy.get("requested", false)) or not bool(underground_policy.get("underground", false)):
			_fail("Underground request did not create level support metadata: %s" % JSON.stringify(underground_policy))
			return false
		if String(layout.get("levels", [])[1].get("kind", "")) != "underground":
			_fail("Second generated level was not marked underground.")
			return false
		if "underground_transit_object_placement_deferred" not in layout.get("unsupported_runtime_features", []):
			_fail("Underground request did not preserve explicit deferred transit metadata.")
			return false
	var scenario: Dictionary = payload.get("scenario_record", {})
	if bool(scenario.get("selection", {}).get("availability", {}).get("campaign", true)) or bool(scenario.get("selection", {}).get("availability", {}).get("skirmish", true)):
		_fail("Zone layout slice adopted generated maps into campaign/skirmish UI.")
		return false
	if scenario.has("save_adoption") or scenario.has("alpha_parity_claim") or String(payload.get("write_policy", "")) != "generated_export_record_no_authored_content_write":
		_fail("Zone layout slice exposed save/writeback/parity claim metadata.")
		return false
	return true

func _assert_area_allocation(layout: Dictionary) -> bool:
	var dimensions: Dictionary = layout.get("dimensions", {})
	var expected_cells := int(dimensions.get("width", 0)) * int(dimensions.get("height", 0))
	for level in layout.get("levels", []):
		if not (level is Dictionary):
			_fail("Layout level is not a dictionary.")
			return false
		var seen := {}
		var total := 0
		var smallest := {"base_size": 999999, "target": 999999}
		var largest := {"base_size": -1, "target": -1}
		for footprint in level.get("zone_footprints", []):
			if not (footprint is Dictionary):
				_fail("Zone footprint is not a dictionary.")
				return false
			var base_size := int(footprint.get("base_size", 0))
			var target := int(footprint.get("target_cell_count", 0))
			var cells: Array = footprint.get("cells", [])
			if base_size <= 0 or target <= 0 or cells.is_empty():
				_fail("Footprint missing base-size target/cells: %s" % JSON.stringify(footprint))
				return false
			if base_size < int(smallest.get("base_size", 999999)):
				smallest = {"base_size": base_size, "target": target}
			if base_size > int(largest.get("base_size", -1)):
				largest = {"base_size": base_size, "target": target}
			if abs(cells.size() - target) > 2:
				_fail("Zone footprint area does not match proportional target: %s" % JSON.stringify({"zone_id": footprint.get("zone_id", ""), "cells": cells.size(), "target": target}))
				return false
			total += cells.size()
			for cell in cells:
				if not (cell is Dictionary):
					_fail("Footprint cell is not a dictionary.")
					return false
				var key := "%d,%d" % [int(cell.get("x", -1)), int(cell.get("y", -1))]
				if seen.has(key):
					_fail("Zone footprints overlap at %s." % key)
					return false
				seen[key] = true
		if total != expected_cells:
			_fail("Zone footprints cover %d cells, expected %d." % [total, expected_cells])
			return false
		if int(largest.get("base_size", 0)) > int(smallest.get("base_size", 0)) and int(largest.get("target", 0)) < int(smallest.get("target", 0)):
			_fail("Zone area targets do not follow catalog base_size ordering.")
			return false
	return true

func _assert_corridor_candidates(layout: Dictionary) -> bool:
	var expected := int(layout.get("template_link_count", 0)) * int(layout.get("dimensions", {}).get("level_count", 1))
	var candidates: Array = layout.get("corridor_candidates", [])
	if candidates.size() != expected:
		_fail("Corridor candidate count %d did not match template links * levels %d." % [candidates.size(), expected])
		return false
	for candidate in candidates:
		if not (candidate is Dictionary):
			_fail("Corridor candidate is not a dictionary.")
			return false
		for key in ["from", "to", "from_anchor", "to_anchor", "level_index", "mode", "intended_connection_class", "materialization_state"]:
			if not candidate.has(key):
				_fail("Corridor candidate missed %s: %s" % [key, JSON.stringify(candidate)])
				return false
		if String(candidate.get("mode", "")) not in ["land", "water"]:
			_fail("Corridor candidate did not expose land/water mode: %s" % JSON.stringify(candidate))
			return false
	return true

func _assert_unsupported_level_request_rejects(generator) -> bool:
	var invalid := {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": "zone-layout-unsupported-level",
		"size": {"preset": "zone_layout_reject", "width": 24, "height": 16, "water_mode": "land", "level_count": 2},
		"player_constraints": {"human_count": 1, "player_count": 2},
		"profile": {"id": "border_gate_compact_profile_v1", "template_id": "border_gate_compact_v1"},
	}
	var generated: Dictionary = generator.generate(invalid)
	if bool(generated.get("ok", true)):
		_fail("Template without underground support unexpectedly generated a layout.")
		return false
	var report: Dictionary = generated.get("report", {})
	if String(report.get("schema_id", "")) != RandomMapGeneratorRulesScript.TEMPLATE_SELECTION_REJECTION_SCHEMA_ID:
		_fail("Unsupported underground request did not return structured rejection: %s" % JSON.stringify(report))
		return false
	if not JSON.stringify(report.get("failures", [])).contains("level_count"):
		_fail("Unsupported underground rejection did not expose level_count reason: %s" % JSON.stringify(report))
		return false
	return true

func _layout_signature(payload: Dictionary) -> String:
	return String(payload.get("staging", {}).get("zone_layout", {}).get("layout_signature", ""))

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
