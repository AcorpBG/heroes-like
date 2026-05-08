extends Node

const REPORT_ID := "NATIVE_RMG_SMALL_H3MAPED_PORT_BOUNDARY_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return

	var service: Variant = ClassDB.instantiate("MapPackageService")
	var metadata: Dictionary = service.get_api_metadata()
	if String(metadata.get("binding_kind", "")) != "native_gdextension" or not bool(metadata.get("native_extension_loaded", false)):
		_fail("Native GDExtension metadata did not prove native load: %s" % JSON.stringify(metadata))
		return
	if not service.get_capabilities().has("native_rmg_small_h3maped_port_boundary"):
		_fail("Native service does not expose the small h3maped port boundary capability.")
		return

	var config := {
		"seed": "small-h3maped-boundary-10184",
		"size": {"width": 36, "height": 36, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_small"},
		"player_constraints": {"human_count": 1, "player_count": 3, "team_mode": "free_for_all"},
	}
	var report: Dictionary = service.inspect_h3maped_small_rmg_port(config)
	if not bool(report.get("ok", false)):
		_fail("Small h3maped port inspection did not accept the supported scope: %s" % JSON.stringify(report))
		return
	if String(report.get("status", "")) != "h3maped_small_template_vector_recovered":
		_fail("Unexpected small h3maped inspection status: %s" % JSON.stringify(report))
		return
	if int(report.get("size_score", -1)) != 1 or int(report.get("h3maped_water_mode_code", -1)) != 0:
		_fail("Small land size score/water code did not follow the recovered formula: %s" % JSON.stringify(report))
		return
	if int(report.get("accepted_template_count", -1)) != 13:
		_fail("Small 1-human/3-player accepted-template vector drifted from recovered catalog evidence: %s" % JSON.stringify(report))
		return
	if String(report.get("selected_template_status", "")) != "blocked_until_h3maped_rng_ported":
		_fail("The port selected a template before the h3maped RNG is ported: %s" % JSON.stringify(report))
		return
	var accepted_ids := _accepted_template_ids(report)
	for required_id in ["h3maped_template_000", "h3maped_template_012", "h3maped_template_048"]:
		if not accepted_ids.has(required_id):
			_fail("Recovered accepted-template vector missed %s: %s" % [required_id, JSON.stringify(report)])
			return
	if accepted_ids.has("h3maped_template_010"):
		_fail("Recovered accepted-template vector included a 2-player-only template for 3 players: %s" % JSON.stringify(report))
		return

	var generated: Dictionary = service.generate_random_map(config)
	if bool(generated.get("ok", true)) or String(generated.get("status", "")) != "h3maped_small_port_generation_not_ready":
		_fail("Small native_catalog_auto generation did not route to the h3maped boundary: %s" % JSON.stringify(generated))
		return
	if String(generated.get("error_code", "")) != "h3maped_rng_and_phase_port_incomplete":
		_fail("Small h3maped boundary did not expose the concrete missing port step: %s" % JSON.stringify(generated))
		return

	var medium_config := config.duplicate(true)
	medium_config["size"] = {"width": 72, "height": 72, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_medium"}
	var medium_report: Dictionary = service.inspect_h3maped_small_rmg_port(medium_config)
	if bool(medium_report.get("ok", true)) or String(medium_report.get("status", "")) != "unsupported_scope":
		_fail("Small h3maped port inspection accepted an out-of-scope medium config: %s" % JSON.stringify(medium_report))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"status": report.get("status", ""),
		"accepted_template_count": report.get("accepted_template_count", 0),
		"generation_status": generated.get("status", ""),
		"unsupported_scope_status": medium_report.get("status", ""),
	})])
	get_tree().quit(0)

func _accepted_template_ids(report: Dictionary) -> Array:
	var result := []
	for item in report.get("accepted_templates", []):
		if item is Dictionary:
			result.append(String(item.get("id", "")))
	return result

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
