extends Node

const AnimationCueCatalogScript = preload("res://scripts/core/AnimationCueCatalog.gd")
const REPORT_ID := "ANIMATION_EVENT_CUE_CATALOG_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report := AnimationCueCatalogScript.event_cue_catalog_report()
	if not bool(report.get("ok", false)):
		_fail("Animation event cue catalog report failed: %s" % report)
		return
	if int(report.get("entry_count", 0)) < 30:
		_fail("Expected at least 30 representative cue catalog entries: %s" % report)
		return
	var surface_counts: Dictionary = report.get("surface_counts", {}) if report.get("surface_counts", {}) is Dictionary else {}
	for surface in ["battle", "overworld", "town", "spell", "artifact", "ui"]:
		if int(surface_counts.get(surface, 0)) <= 0:
			_fail("Missing required surface %s: %s" % [surface, report])
			return
	var fallback_counts: Dictionary = report.get("fallback_counts", {}) if report.get("fallback_counts", {}) is Dictionary else {}
	if int(fallback_counts.get("reduced_motion", 0)) != int(report.get("entry_count", 0)):
		_fail("Reduced-motion fallback coverage is incomplete: %s" % report)
		return
	if int(fallback_counts.get("fast_mode", 0)) != int(report.get("entry_count", 0)):
		_fail("Fast-mode fallback coverage is incomplete: %s" % report)
		return
	var state_family_counts: Dictionary = report.get("state_family_counts", {}) if report.get("state_family_counts", {}) is Dictionary else {}
	for family in ["move", "attack", "hit", "death", "status", "defend", "captured", "depleted", "route", "ambient"]:
		if int(state_family_counts.get(family, 0)) <= 0:
			_fail("Missing required state family %s: %s" % [family, report])
			return
	var validation_tag_counts: Dictionary = report.get("validation_tag_counts", {}) if report.get("validation_tag_counts", {}) is Dictionary else {}
	for tag in ["battle", "overworld", "town", "spell", "artifact", "ui", "resolved_event"]:
		if int(validation_tag_counts.get(tag, 0)) <= 0:
			_fail("Missing validation tag %s: %s" % [tag, report])
			return
	var runtime_policy: Dictionary = report.get("runtime_policy", {}) if report.get("runtime_policy", {}) is Dictionary else {}
	for blocked_policy in ["save_version_bump", "final_sprite_import", "final_vfx_import", "final_audio_import", "renderer_asset_pipeline", "playback_runtime", "broad_ui_polish"]:
		if bool(runtime_policy.get(blocked_policy, true)):
			_fail("Runtime policy crossed slice boundary %s: %s" % [blocked_policy, runtime_policy])
			return

	var fast_cue := AnimationCueCatalogScript.cue_for_event("battle_unit_move", "fast")
	if String(fast_cue.get("selected_fallback_tag", "")) != "snap_to_destination":
		_fail("Fast fallback lookup failed for battle_unit_move: %s" % fast_cue)
		return
	var reduced_cue := AnimationCueCatalogScript.cue_for_event("overworld_object_ambient", "reduced_motion")
	if String(reduced_cue.get("selected_fallback_tag", "")) != "static_object_pose":
		_fail("Reduced-motion fallback lookup failed for overworld_object_ambient: %s" % reduced_cue)
		return
	if not _assert_public_payload("animation cue public payload", report.get("public_payload", {})):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_id": String(report.get("schema_id", "")),
		"schema_status": String(report.get("schema_status", "")),
		"entry_count": int(report.get("entry_count", 0)),
		"surface_counts": surface_counts,
		"state_family_counts": state_family_counts,
		"fallback_counts": fallback_counts,
		"placeholder_counts": report.get("placeholder_counts", {}),
		"runtime_policy": runtime_policy,
		"checked_events": [
			"battle_unit_move",
			"overworld_object_captured",
			"town_building_built",
			"spell_cast_battle",
			"artifact_equipped",
			"ui_invalid_action"
		],
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

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
