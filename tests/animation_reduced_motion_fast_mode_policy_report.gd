extends Node

const AnimationCueCatalogScript = preload("res://scripts/core/AnimationCueCatalog.gd")
const REPORT_ID := "ANIMATION_REDUCED_MOTION_FAST_MODE_POLICY_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report := AnimationCueCatalogScript.animation_preference_policy_report()
	if not bool(report.get("ok", false)):
		_fail("Animation preference policy report failed: %s" % report)
		return
	if String(report.get("schema_id", "")) != "animation_playback_preference_policy_v1":
		_fail("Animation preference policy report used an unexpected schema: %s" % report)
		return
	if int(report.get("troop_policy_count", 0)) < 4:
		_fail("Animation preference policy did not cover enough battle troop cues: %s" % report)
		return
	if int(report.get("object_policy_count", 0)) < 4:
		_fail("Animation preference policy did not cover enough overworld object cues: %s" % report)
		return

	var normal_move := AnimationCueCatalogScript.cue_playback_policy_for_event("battle_unit_move")
	if String(normal_move.get("selected_animation_state", "")) != "move_path_step" or String(normal_move.get("selected_fallback_tag", "")) != "":
		_fail("Normal battle troop move policy did not keep the authored state: %s" % normal_move)
		return
	var reduced_move := AnimationCueCatalogScript.cue_playback_policy_for_event("battle_unit_move", {"reduced_motion": true})
	if String(reduced_move.get("selected_fallback_tag", "")) != "path_marker_snap" or bool(reduced_move.get("allows_large_motion", true)):
		_fail("Reduced-motion battle troop move policy did not choose the static path fallback: %s" % reduced_move)
		return
	var fast_move := AnimationCueCatalogScript.cue_playback_policy_for_event("battle_unit_move", {"fast_mode": true})
	if String(fast_move.get("selected_fallback_tag", "")) != "snap_to_destination" or String(fast_move.get("selected_playback_policy", "")) != "fast_resolve":
		_fail("Fast-mode battle troop move policy did not choose snap fast resolution: %s" % fast_move)
		return
	var combined_move := AnimationCueCatalogScript.cue_playback_policy_for_event("battle_unit_move", {"reduced_motion": true, "fast_mode": true})
	if String(combined_move.get("selected_fallback_tag", "")) != "path_marker_snap" or String(combined_move.get("timing_preference", "")) != "fast":
		_fail("Combined battle troop move policy did not use reduced visual fallback with fast timing: %s" % combined_move)
		return

	var reduced_attack := AnimationCueCatalogScript.cue_playback_policy_for_event("battle_unit_melee_attack", {"reduced_motion": true})
	if String(reduced_attack.get("selected_fallback_tag", "")) != "directional_attack_icon":
		_fail("Reduced-motion troop attack policy did not preserve attack direction readability: %s" % reduced_attack)
		return
	var fast_hit := AnimationCueCatalogScript.cue_playback_policy_for_event("battle_unit_hit", {"fast_mode": true})
	if String(fast_hit.get("selected_fallback_tag", "")) != "damage_badge_instant":
		_fail("Fast-mode troop hit policy did not preserve damage feedback: %s" % fast_hit)
		return

	var reduced_capture := AnimationCueCatalogScript.cue_playback_policy_for_event("overworld_object_captured", {"reduced_motion": true})
	if String(reduced_capture.get("selected_fallback_tag", "")) != "ownership_badge_swap" or bool(reduced_capture.get("allows_loop_motion", true)):
		_fail("Reduced-motion object capture policy did not choose ownership badge fallback: %s" % reduced_capture)
		return
	var fast_capture := AnimationCueCatalogScript.cue_playback_policy_for_event("overworld_object_captured", {"fast_mode": true})
	if String(fast_capture.get("selected_fallback_tag", "")) != "capture_badge_snap":
		_fail("Fast-mode object capture policy did not choose capture snap fallback: %s" % fast_capture)
		return
	var combined_capture := AnimationCueCatalogScript.cue_playback_policy_for_event("overworld_object_captured", {"reduced_motion": true, "fast_mode": true})
	if String(combined_capture.get("selected_fallback_tag", "")) != "ownership_badge_swap" or String(combined_capture.get("combined_policy", "")) != "reduced_motion_visual_fast_timing":
		_fail("Combined object capture policy did not keep reduced visual fallback with fast timing: %s" % combined_capture)
		return
	var reduced_ambient := AnimationCueCatalogScript.cue_playback_policy_for_event("overworld_object_ambient", {"reduced_motion": true})
	if String(reduced_ambient.get("selected_fallback_tag", "")) != "static_object_pose":
		_fail("Reduced-motion object ambient policy did not suppress object loop motion: %s" % reduced_ambient)
		return

	var settings_preferences := SettingsService.animation_preferences({"reduce_motion": true, "fast_mode": true})
	var normalized_settings := AnimationCueCatalogScript.normalize_animation_preferences(settings_preferences)
	if String(normalized_settings.get("mode", "")) != "reduced_motion_fast":
		_fail("Settings preference helper did not normalize combined animation preferences: %s" % normalized_settings)
		return

	var covered_surfaces: Dictionary = report.get("covered_surfaces", {}) if report.get("covered_surfaces", {}) is Dictionary else {}
	for surface in ["battle", "overworld", "town", "spell", "artifact", "ui"]:
		if int(covered_surfaces.get(surface, 0)) <= 0:
			_fail("Animation policy report missed surface %s: %s" % [surface, report])
			return
	if not _assert_public_payload("animation policy public payload", report.get("public_payload", {})):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_id": String(report.get("schema_id", "")),
		"schema_status": String(report.get("schema_status", "")),
		"representative_event_count": int(report.get("representative_event_count", 0)),
		"covered_surfaces": covered_surfaces,
		"covered_subjects": report.get("covered_subjects", {}),
		"troop_policy_count": int(report.get("troop_policy_count", 0)),
		"object_policy_count": int(report.get("object_policy_count", 0)),
		"checked_events": [
			"battle_unit_move",
			"battle_unit_melee_attack",
			"battle_unit_hit",
			"overworld_object_captured",
			"overworld_object_ambient",
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
