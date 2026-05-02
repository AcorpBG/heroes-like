extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_RESOURCE_ENCOUNTER_FAIRNESS_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": "terrain-town-road-10184",
		"size": {"preset": "fairness_test", "width": 22, "height": 14},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "resource_encounter_fairness_profile",
			"label": "Resource Encounter Fairness Profile",
			"terrain_ids": ["grass", "grass", "rough", "dirt", "rough", "water"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
			"guard_strength_profile": "core_low",
		},
	}

	var generator = RandomMapGeneratorRulesScript.new()
	var generated: Dictionary = generator.generate(config)
	if not bool(generated.get("ok", false)):
		_fail("Generated payload validation failed: %s" % JSON.stringify(generated.get("report", {})))
		return
	var payload: Dictionary = generated.get("generated_map", {})
	var embedded: Dictionary = payload.get("staging", {}).get("fairness_report", {})
	if String(embedded.get("schema_id", "")) != "random_map_resource_encounter_fairness_report_v1":
		_fail("Generated payload did not expose fairness report schema.")
		return
	if String(embedded.get("status", "")) == "fail":
		_fail("Happy-path generated fairness profile failed: %s" % JSON.stringify(embedded))
		return
	if String(generated.get("report", {}).get("fairness_status", "")) == "fail":
		_fail("Validation report surfaced a failing fairness status.")
		return
	if not _assert_happy_path_metrics(embedded):
		return

	var recomputed: Dictionary = generator.resource_encounter_fairness_report(payload)
	if String(recomputed.get("status", "")) != String(embedded.get("status", "")):
		_fail("Recomputed fairness report did not match embedded status.")
		return

	var warning_payload: Dictionary = payload.duplicate(true)
	_force_contest_distance_spread(warning_payload, 15)
	var warning_report: Dictionary = generator.resource_encounter_fairness_report(warning_payload)
	if String(warning_report.get("status", "")) != "warning":
		_fail("Expected warning classification for uneven contest-route distance spread: %s" % JSON.stringify(warning_report))
		return

	var fail_payload: Dictionary = payload.duplicate(true)
	_remove_first_start_resources(fail_payload)
	var fail_report: Dictionary = generator.resource_encounter_fairness_report(fail_payload)
	if String(fail_report.get("status", "")) != "fail":
		_fail("Expected fail classification when a start loses early resources: %s" % JSON.stringify(fail_report))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"stable_signature": payload.get("stable_signature", ""),
		"happy_status": embedded.get("status", ""),
		"warning_status": warning_report.get("status", ""),
		"fail_status": fail_report.get("status", ""),
		"summary": embedded.get("summary", {}),
		"early_resource_support": embedded.get("early_resource_support", {}),
		"guard_pressure": {
			"status": embedded.get("guard_pressure", {}).get("status", ""),
			"route_guard_count": embedded.get("guard_pressure", {}).get("route_guards", []).size(),
			"pressure_by_start_zone": embedded.get("guard_pressure", {}).get("pressure_by_start_zone", {}),
		},
	})])
	get_tree().quit(0)

func _assert_happy_path_metrics(report: Dictionary) -> bool:
	var support: Dictionary = report.get("early_resource_support", {})
	if support.get("per_start", []).size() != 3:
		_fail("Expected early resource support per generated start.")
		return false
	for start in support.get("per_start", []):
		if not (start is Dictionary) or String(start.get("status", "")) == "fail":
			_fail("Early resource support failed for a start: %s" % JSON.stringify(start))
			return false
		var totals: Dictionary = start.get("totals", {})
		for resource_id in ["gold", "wood", "ore"]:
			if int(totals.get(resource_id, 0)) < int(RandomMapGeneratorRulesScript.EARLY_RESOURCE_MINIMUMS.get(resource_id, 0)):
				_fail("Start missed %s minimum: %s" % [resource_id, JSON.stringify(start)])
				return false
	var guard_pressure: Dictionary = report.get("guard_pressure", {})
	if guard_pressure.get("route_guards", []).is_empty():
		_fail("Fairness report missed route guard pressure records.")
		return false
	var risk_classes := {}
	for record in guard_pressure.get("route_guards", []):
		if record is Dictionary:
			risk_classes[String(record.get("risk_class", ""))] = true
	if not risk_classes.has("low") or not risk_classes.has("medium") or not risk_classes.has("wide_unguarded_normal_guard_suppressed"):
		_fail("Fairness report missed expected guard risk classes: %s" % JSON.stringify(risk_classes))
		return false
	var contested: Dictionary = report.get("contested_front_distribution", {})
	if String(contested.get("status", "")) == "fail" or contested.get("per_start", []).size() != 3:
		_fail("Contest front distribution failed happy-path coverage: %s" % JSON.stringify(contested))
		return false
	var distances: Dictionary = report.get("travel_distance_comparisons", {})
	if String(distances.get("status", "")) == "fail" or distances.get("per_start", []).size() != 3:
		_fail("Travel distance comparison failed happy-path coverage: %s" % JSON.stringify(distances))
		return false
	return true

func _force_contest_distance_spread(payload: Dictionary, spread: int) -> void:
	var edges: Array = payload.get("staging", {}).get("route_graph", {}).get("edges", [])
	var first := true
	for edge in edges:
		if not (edge is Dictionary) or String(edge.get("role", "")) != "contest_route":
			continue
		edge["path_found"] = true
		edge["path_length"] = 10 + spread if first else 10
		first = false

func _remove_first_start_resources(payload: Dictionary) -> void:
	var towns: Array = payload.get("scenario_record", {}).get("towns", [])
	if towns.is_empty() or not (towns[0] is Dictionary):
		return
	var first_zone_id := String(towns[0].get("zone_id", ""))
	var kept := []
	for resource in payload.get("scenario_record", {}).get("resource_nodes", []):
		if resource is Dictionary and String(resource.get("zone_id", "")) != first_zone_id:
			kept.append(resource)
	payload["scenario_record"]["resource_nodes"] = kept

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
