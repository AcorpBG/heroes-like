extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_TEMPLATE_CATALOG_GRAMMAR_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var base_config := {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": "template-catalog-grammar-10184",
		"size": {"preset": "catalog_test", "width": 24, "height": 16},
		"player_constraints": {"human_count": 1, "computer_count": 2},
		"profile": {
			"id": "border_gate_compact_profile_v1",
			"template_id": "border_gate_compact_v1",
		},
	}
	var alternate_config := base_config.duplicate(true)
	alternate_config["profile"]["id"] = "frontier_spokes_profile_v1"
	alternate_config["profile"]["template_id"] = "frontier_spokes_v1"

	var generator = RandomMapGeneratorRulesScript.new()
	var catalog_report: Dictionary = generator.template_catalog_report(base_config)
	if not bool(catalog_report.get("ok", false)):
		_fail("Catalog report failed: %s" % JSON.stringify(catalog_report))
		return
	if int(catalog_report.get("template_count", 0)) < 2 or int(catalog_report.get("profile_count", 0)) < 2:
		_fail("Catalog must expose multiple template and profile records: %s" % JSON.stringify(catalog_report))
		return
	if String(catalog_report.get("selected_template_id", "")) != "border_gate_compact_v1":
		_fail("Catalog selection did not preserve requested template id: %s" % JSON.stringify(catalog_report))
		return

	var first: Dictionary = generator.generate(base_config)
	var second: Dictionary = generator.generate(base_config)
	var alternate: Dictionary = generator.generate(alternate_config)
	if not bool(first.get("ok", false)) or not bool(second.get("ok", false)) or not bool(alternate.get("ok", false)):
		_fail("Generated catalog payload validation failed: %s / %s / %s" % [JSON.stringify(first.get("report", {})), JSON.stringify(second.get("report", {})), JSON.stringify(alternate.get("report", {}))])
		return

	var payload: Dictionary = first.get("generated_map", {})
	var repeated_payload: Dictionary = second.get("generated_map", {})
	var alternate_payload: Dictionary = alternate.get("generated_map", {})
	if String(payload.get("stable_signature", "")) != String(repeated_payload.get("stable_signature", "")):
		_fail("Same seed and template did not produce a stable signature.")
		return
	if String(payload.get("stable_signature", "")) == String(alternate_payload.get("stable_signature", "")):
		_fail("Different template id did not change generated payload signature.")
		return
	if not _assert_template_metadata(payload, "border_gate_compact_v1"):
		return
	if not _assert_catalog_graph(payload):
		return
	if not _assert_special_connection_semantics(payload):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"catalog": {
			"template_count": catalog_report.get("template_count", 0),
			"profile_count": catalog_report.get("profile_count", 0),
			"selected_template_id": catalog_report.get("selected_template_id", ""),
		},
		"stable_signature": payload.get("stable_signature", ""),
		"alternate_template_signature": alternate_payload.get("stable_signature", ""),
		"metadata_template_id": payload.get("metadata", {}).get("template_id", ""),
		"phase_template": _template_phase_summary(payload),
		"route_edge_count": payload.get("staging", {}).get("route_graph", {}).get("edges", []).size(),
		"fairness_guard_pressure": payload.get("staging", {}).get("fairness_report", {}).get("guard_pressure", {}),
	})])
	get_tree().quit(0)

func _assert_template_metadata(payload: Dictionary, expected_template_id: String) -> bool:
	var metadata: Dictionary = payload.get("metadata", {})
	if String(metadata.get("template_id", "")) != expected_template_id:
		_fail("Payload metadata missed selected template id: %s" % JSON.stringify(metadata))
		return false
	var staging: Dictionary = payload.get("staging", {})
	if String(staging.get("template", {}).get("id", "")) != expected_template_id:
		_fail("Staging template missed selected template id: %s" % JSON.stringify(staging.get("template", {})))
		return false
	var phase_summary := _template_phase_summary(payload)
	if String(phase_summary.get("template_id", "")) != expected_template_id:
		_fail("Phase pipeline missed selected template id: %s" % JSON.stringify(phase_summary))
		return false
	return true

func _assert_catalog_graph(payload: Dictionary) -> bool:
	var staging: Dictionary = payload.get("staging", {})
	var template: Dictionary = staging.get("template", {})
	var zones: Array = template.get("zones", [])
	var links: Array = template.get("links", [])
	if zones.size() < 6 or links.size() < 6:
		_fail("Catalog template graph was not preserved in staging: %s" % JSON.stringify(template))
		return false
	var zone_ids := {}
	for zone in zones:
		if zone is Dictionary:
			zone_ids[String(zone.get("id", ""))] = true
	for required_zone in ["start_1", "start_2", "start_3", "gate_1"]:
		if not zone_ids.has(required_zone):
			_fail("Catalog zone %s missing from runtime template graph." % required_zone)
			return false
	var route_edges: Array = staging.get("route_graph", {}).get("edges", [])
	for link in links:
		if not (link is Dictionary):
			continue
		var found := false
		for edge in route_edges:
			if edge is Dictionary and String(edge.get("from", "")) == String(link.get("from", "")) and String(edge.get("to", "")) == String(link.get("to", "")):
				found = true
				break
		if not found:
			_fail("Catalog link did not survive into route graph: %s" % JSON.stringify(link))
			return false
	return true

func _assert_special_connection_semantics(payload: Dictionary) -> bool:
	var route_edges: Array = payload.get("staging", {}).get("route_graph", {}).get("edges", [])
	var has_wide := false
	var has_border := false
	var has_guard_value := false
	for edge in route_edges:
		if not (edge is Dictionary):
			continue
		if bool(edge.get("wide", false)):
			has_wide = true
			if int(edge.get("guard_value", -1)) != 0:
				_fail("Wide catalog edge should preserve its zero normal guard value: %s" % JSON.stringify(edge))
				return false
		if bool(edge.get("border_guard", false)):
			has_border = true
			if not String(edge.get("connectivity_classification", "")).contains("border_guard"):
				_fail("Border guard edge did not keep special route classification: %s" % JSON.stringify(edge))
				return false
		if int(edge.get("guard_value", 0)) > 0:
			has_guard_value = true
	if not has_wide or not has_border or not has_guard_value:
		_fail("Route graph missed wide/border/guard semantics.")
		return false
	var guard_pressure: Dictionary = payload.get("staging", {}).get("fairness_report", {}).get("guard_pressure", {})
	var saw_wide_report := false
	var saw_border_report := false
	for record in guard_pressure.get("route_guards", []):
		if not (record is Dictionary):
			continue
		if bool(record.get("wide_suppresses_normal_guard", false)) and int(record.get("effective_guard_pressure", -1)) == 0:
			saw_wide_report = true
		if bool(record.get("border_guard_special_mode", false)) and String(record.get("risk_class", "")) == "special_border_guard":
			saw_border_report = true
	if not saw_wide_report or not saw_border_report:
		_fail("Fairness output missed special connection semantics: %s" % JSON.stringify(guard_pressure))
		return false
	return true

func _template_phase_summary(payload: Dictionary) -> Dictionary:
	for phase in payload.get("phase_pipeline", []):
		if phase is Dictionary and String(phase.get("phase", "")) == "template_profile":
			return phase.get("summary", {})
	return {}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
