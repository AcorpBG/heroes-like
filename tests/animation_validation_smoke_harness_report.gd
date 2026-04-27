extends Node

const AnimationCueCatalogScript = preload("res://scripts/core/AnimationCueCatalog.gd")
const REPORT_ID := "ANIMATION_VALIDATION_SMOKE_HARNESS_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report := AnimationCueCatalogScript.animation_validation_smoke_harness_report()
	if not bool(report.get("ok", false)):
		_fail("Animation validation smoke harness failed: %s" % report)
		return
	if String(report.get("schema_id", "")) != "animation_validation_smoke_harness_v1":
		_fail("Unexpected animation smoke harness schema: %s" % report)
		return

	var individual_reports: Dictionary = report.get("individual_reports", {}) if report.get("individual_reports", {}) is Dictionary else {}
	for report_name in ["catalog", "policy", "battle_troop", "overworld_object"]:
		var report_status: Dictionary = individual_reports.get(report_name, {}) if individual_reports.get(report_name, {}) is Dictionary else {}
		if not bool(report_status.get("ok", false)):
			_fail("Dependency report was not ok for %s: %s" % [report_name, individual_reports])
			return

	var surface_counts: Dictionary = report.get("surface_counts", {}) if report.get("surface_counts", {}) is Dictionary else {}
	for surface in ["battle", "overworld", "town", "spell", "artifact", "ui"]:
		if int(surface_counts.get(surface, 0)) <= 0:
			_fail("Smoke harness missed surface %s: %s" % [surface, report])
			return

	var representative_event_count := int(report.get("representative_event_count", 0))
	if representative_event_count < 14:
		_fail("Smoke harness representative event coverage is too small: %s" % report)
		return
	var mode_counts: Dictionary = report.get("mode_counts", {}) if report.get("mode_counts", {}) is Dictionary else {}
	for mode in ["normal", "reduced_motion", "fast", "reduced_motion_fast"]:
		if int(mode_counts.get(mode, 0)) != representative_event_count:
			_fail("Smoke harness did not resolve every representative event in %s mode: %s" % [mode, report])
			return

	var matrix: Dictionary = report.get("event_policy_matrix", {}) if report.get("event_policy_matrix", {}) is Dictionary else {}
	if not _assert_event_case(matrix, "battle", "battle_unit_move", "move", "path_marker_snap", "snap_to_destination"):
		return
	if not _assert_event_case(matrix, "overworld", "overworld_object_captured", "captured", "ownership_badge_swap", "capture_badge_snap"):
		return
	if not _assert_event_case(matrix, "town", "town_building_built", "construction", "building_badge_added", "build_badge_snap"):
		return
	if not _assert_event_case(matrix, "spell", "spell_cast_battle", "spell_cast", "spell_school_icon_anchor", "spell_school_flash"):
		return
	if not _assert_event_case(matrix, "artifact", "artifact_equipped", "equip", "slot_badge_added", "slot_badge_snap"):
		return
	if not _assert_event_case(matrix, "ui", "ui_invalid_action", "microinteraction", "invalid_icon_static", "invalid_icon_instant"):
		return

	var runtime_policy: Dictionary = report.get("runtime_policy", {}) if report.get("runtime_policy", {}) is Dictionary else {}
	for blocked_policy in ["save_version_bump", "final_sprite_import", "final_vfx_import", "final_audio_import", "renderer_asset_pipeline", "playback_runtime", "broad_ui_polish"]:
		if bool(runtime_policy.get(blocked_policy, true)):
			_fail("Smoke harness crossed runtime policy boundary %s: %s" % [blocked_policy, runtime_policy])
			return
	if not _assert_public_payload("animation smoke public payload", report.get("public_payload", {})):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_id": String(report.get("schema_id", "")),
		"schema_status": String(report.get("schema_status", "")),
		"representative_event_count": representative_event_count,
		"surface_counts": surface_counts,
		"mode_counts": mode_counts,
		"individual_reports": individual_reports,
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_event_case(matrix: Dictionary, surface: String, event_id: String, expected_family: String, expected_reduced: String, expected_fast: String) -> bool:
	var surface_events: Dictionary = matrix.get(surface, {}) if matrix.get(surface, {}) is Dictionary else {}
	var event_case: Dictionary = surface_events.get(event_id, {}) if surface_events.get(event_id, {}) is Dictionary else {}
	if String(event_case.get("state_family", "")) != expected_family:
		_fail("%s did not map to expected state family %s: %s" % [event_id, expected_family, event_case])
		return false
	var policy_cases: Dictionary = event_case.get("policy_cases", {}) if event_case.get("policy_cases", {}) is Dictionary else {}
	var reduced_case: Dictionary = policy_cases.get("reduced_motion", {}) if policy_cases.get("reduced_motion", {}) is Dictionary else {}
	var fast_case: Dictionary = policy_cases.get("fast", {}) if policy_cases.get("fast", {}) is Dictionary else {}
	var combined_case: Dictionary = policy_cases.get("reduced_motion_fast", {}) if policy_cases.get("reduced_motion_fast", {}) is Dictionary else {}
	if String(reduced_case.get("selected_fallback_tag", "")) != expected_reduced:
		_fail("%s reduced-motion fallback mismatch: %s" % [event_id, policy_cases])
		return false
	if String(fast_case.get("selected_fallback_tag", "")) != expected_fast or String(fast_case.get("selected_playback_policy", "")) != "fast_resolve":
		_fail("%s fast-mode fallback mismatch: %s" % [event_id, policy_cases])
		return false
	if String(combined_case.get("selected_fallback_tag", "")) != expected_reduced or String(combined_case.get("timing_preference", "")) != "fast":
		_fail("%s combined policy mismatch: %s" % [event_id, policy_cases])
		return false
	return true

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
