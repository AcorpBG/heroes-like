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
	if String(metadata.get("native_rmg_generation_authority", "")) != "h3maped_small_reset_only" \
			or bool(metadata.get("native_rmg_runtime_generation_allowed", true)):
		_fail("Native RMG reset gate is not active: %s" % JSON.stringify(metadata))
		return

	var config := {
		"seed": "1",
		"size": {"width": 36, "height": 36, "level_count": 1, "water_mode": "land", "size_class_id": "homm3_small"},
		"player_constraints": {"human_count": 1, "player_count": 3, "team_mode": "free_for_all"},
	}

	var report: Dictionary = service.inspect_h3maped_small_rmg_port(config)
	if not bool(report.get("ok", false)):
		_fail("Fresh small h3maped boundary rejected the supported scope: %s" % JSON.stringify(report))
		return
	if String(report.get("schema_id", "")) != "aurelion_native_rmg_small_h3maped_fresh_start_boundary_v1":
		_fail("The active report is not the fresh-start boundary: %s" % JSON.stringify(report))
		return
	if String(report.get("implementation_policy", "")) != "fresh_small_only_h3maped_exe_boundary_no_catalog_auto_no_hash_selection_no_report_treadmill_no_runtime_fallback":
		_fail("Fresh-start policy drifted: %s" % JSON.stringify(report))
		return
	if bool(report.get("runtime_generation_allowed", true)) or bool(report.get("partial_materialized_payload_public_api", true)):
		_fail("Fresh-start boundary exposed runtime output: %s" % JSON.stringify(report))
		return
	if report.has("small_generation_state") or report.has("private_generation_context"):
		_fail("Fresh-start boundary still exposes the old private phase ledger: %s" % JSON.stringify(report))
		return
	if String(report.get("archived_report_treadmill_path", "")) != "src/gdextension/src/archived_h3maped_small_rmg_report_treadmill_20260513.cpp":
		_fail("The report-treadmill implementation was not archived: %s" % JSON.stringify(report))
		return

	var binary: Dictionary = report.get("h3maped_binary", {})
	if not bool(binary.get("ok", false)) \
			or String(binary.get("status", "")) != "verified_reset_anchor" \
			or not bool(binary.get("mz_header_present", false)) \
			or not bool(binary.get("sha256_matches", false)) \
			or String(binary.get("actual_sha256", "")) != "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37":
		_fail("h3maped.exe anchor verification failed: %s" % JSON.stringify(binary))
		return

	if int(report.get("size_score", -1)) != 1 \
			or int(report.get("h3maped_water_mode_code", -1)) != 0 \
			or int(report.get("accepted_template_count", -1)) != 13:
		_fail("Small land template boundary changed: %s" % JSON.stringify(report))
		return

	var selection: Dictionary = report.get("selection_identity", {})
	if not bool(selection.get("ok", false)) \
			or String(selection.get("template_selection_mode", "")) != "h3maped_exe_rng" \
			or String(selection.get("source_template_id", "")) != "h3maped_template_018" \
			or int(selection.get("source_catalog_index", -1)) != 18 \
			or String(selection.get("adapted_template_id", "")) != "translated_rmg_template_019_v1" \
			or int(selection.get("selected_vector_index", -1)) != 2 \
			or int(selection.get("rng_first_value", -1)) != 41 \
			or int(selection.get("rng_state_after_selection_uint32", -1)) != 2745024:
		_fail("h3maped RNG template selection drifted: %s" % JSON.stringify(selection))
		return

	var backlog: Array = report.get("fresh_phase_backlog", [])
	if backlog.size() != 10 \
			or String(backlog[0].get("id", "")) != "template_selection" \
			or String(backlog[0].get("status", "")) != "active_boundary" \
			or String(backlog[1].get("id", "")) != "player_slot_assignment" \
			or String(backlog[1].get("status", "")) != "pending_runtime_port" \
			or String(backlog[7].get("id", "")) != "roads_and_rivers" \
			or String(backlog[8].get("id", "")) != "connections_blockers_and_guards" \
			or String(backlog[9].get("id", "")) != "final_h3m_writeout":
		_fail("Fresh h3maped phase backlog drifted: %s" % JSON.stringify(backlog))
		return
	for phase in backlog:
		if bool(phase.get("materializes_public_output", true)):
			_fail("Fresh backlog phase unexpectedly materializes public output: %s" % JSON.stringify(phase))
			return

	var generated: Dictionary = service.generate_random_map(config, {})
	if bool(generated.get("ok", true)) \
			or String(generated.get("generation_status", "")) != "h3maped_small_clean_restart_generation_not_ready" \
			or bool(generated.get("runtime_generation_allowed", true)):
		_fail("Fresh h3maped boundary must keep runtime generation blocked: %s" % JSON.stringify(generated))
		return

	print("%s: PASS" % REPORT_ID)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
