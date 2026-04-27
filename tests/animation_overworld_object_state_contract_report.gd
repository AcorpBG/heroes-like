extends Node

const AnimationCueCatalogScript = preload("res://scripts/core/AnimationCueCatalog.gd")
const REPORT_ID := "ANIMATION_OVERWORLD_OBJECT_STATE_CONTRACT_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report := AnimationCueCatalogScript.overworld_object_state_contract_report()
	if not bool(report.get("ok", false)):
		_fail("Overworld object state contract failed: %s" % report)
		return
	if String(report.get("schema_id", "")) != "overworld_object_state_contract_v1":
		_fail("Unexpected overworld object state contract schema: %s" % report)
		return

	var expected_events := {
		"idle": "overworld_object_idle",
		"active": "overworld_object_active",
		"visited": "overworld_object_visited",
		"depleted": "overworld_object_depleted",
		"captured": "overworld_object_captured",
		"blocked": "overworld_object_blocked",
		"guarded": "overworld_object_guarded",
		"route-open": "overworld_route_open",
		"route-closed": "overworld_route_closed",
		"ambient-loop": "overworld_object_ambient",
	}
	var state_family_counts: Dictionary = report.get("state_family_counts", {}) if report.get("state_family_counts", {}) is Dictionary else {}
	for family in expected_events.keys():
		if int(state_family_counts.get(family, 0)) <= 0:
			_fail("Missing overworld object state family %s: %s" % [family, report])
			return

	var representative_events: Dictionary = report.get("representative_events", {}) if report.get("representative_events", {}) is Dictionary else {}
	for family in expected_events.keys():
		if String(representative_events.get(family, "")) != String(expected_events[family]):
			_fail("Representative event mismatch for %s: %s" % [family, report])
			return

	var subject_counts: Dictionary = report.get("subject_counts", {}) if report.get("subject_counts", {}) is Dictionary else {}
	for subject in ["map_object", "resource_site"]:
		if int(subject_counts.get(subject, 0)) <= 0:
			_fail("Missing subject coverage %s: %s" % [subject, report])
			return
	if int(report.get("town_shared_entry_count", 0)) < 1:
		_fail("Shared town object-state hook is missing: %s" % report)
		return

	var fallback_counts: Dictionary = report.get("fallback_counts", {}) if report.get("fallback_counts", {}) is Dictionary else {}
	var object_entry_count := int(report.get("overworld_object_entry_count", 0))
	if object_entry_count < expected_events.size():
		_fail("Overworld object entry coverage is too small: %s" % report)
		return
	if int(fallback_counts.get("reduced_motion", 0)) != object_entry_count:
		_fail("Overworld object reduced-motion fallback coverage is incomplete: %s" % report)
		return
	if int(fallback_counts.get("fast_mode", 0)) != object_entry_count:
		_fail("Overworld object fast-mode fallback coverage is incomplete: %s" % report)
		return
	if int(report.get("producer_ref_count", 0)) < expected_events.size():
		_fail("Overworld object producer refs are incomplete: %s" % report)
		return

	var policy_cases: Dictionary = report.get("policy_cases", {}) if report.get("policy_cases", {}) is Dictionary else {}
	var guarded_policy: Dictionary = policy_cases.get("overworld_object_guarded", {}) if policy_cases.get("overworld_object_guarded", {}) is Dictionary else {}
	var guarded_reduced: Dictionary = guarded_policy.get("reduced_motion", {}) if guarded_policy.get("reduced_motion", {}) is Dictionary else {}
	var guarded_fast: Dictionary = guarded_policy.get("fast", {}) if guarded_policy.get("fast", {}) is Dictionary else {}
	var guarded_combined: Dictionary = guarded_policy.get("reduced_motion_fast", {}) if guarded_policy.get("reduced_motion_fast", {}) is Dictionary else {}
	if String(guarded_reduced.get("selected_fallback_tag", "")) != "guard_badge_static":
		_fail("Guarded reduced-motion fallback was not selected: %s" % guarded_policy)
		return
	if String(guarded_fast.get("selected_fallback_tag", "")) != "guard_badge_flash" or String(guarded_fast.get("selected_playback_policy", "")) != "fast_resolve":
		_fail("Guarded fast-mode fallback was not selected: %s" % guarded_policy)
		return
	if String(guarded_combined.get("selected_fallback_tag", "")) != "guard_badge_static" or String(guarded_combined.get("timing_preference", "")) != "fast":
		_fail("Guarded combined policy did not use reduced visuals with fast timing: %s" % guarded_policy)
		return

	var ambient_policy: Dictionary = policy_cases.get("overworld_object_ambient", {}) if policy_cases.get("overworld_object_ambient", {}) is Dictionary else {}
	var ambient_reduced: Dictionary = ambient_policy.get("reduced_motion", {}) if ambient_policy.get("reduced_motion", {}) is Dictionary else {}
	if String(ambient_reduced.get("selected_fallback_tag", "")) != "static_object_pose":
		_fail("Ambient-loop reduced-motion fallback was not selected: %s" % ambient_policy)
		return

	var content_context: Dictionary = report.get("content_context", {}) if report.get("content_context", {}) is Dictionary else {}
	var object_class_counts: Dictionary = content_context.get("object_class_counts", {}) if content_context.get("object_class_counts", {}) is Dictionary else {}
	for object_class in ["pickup", "mine", "neutral_dwelling", "guarded_reward_site", "transit_object", "blocker", "faction_landmark"]:
		if int(object_class_counts.get(object_class, 0)) <= 0:
			_fail("Content context missed object class %s: %s" % [object_class, content_context])
			return

	if not _assert_public_payload("overworld object state public payload", report.get("public_payload", {})):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_id": String(report.get("schema_id", "")),
		"schema_status": String(report.get("schema_status", "")),
		"overworld_object_entry_count": object_entry_count,
		"town_shared_entry_count": int(report.get("town_shared_entry_count", 0)),
		"state_family_counts": state_family_counts,
		"subject_counts": subject_counts,
		"representative_events": representative_events,
		"fallback_counts": fallback_counts,
		"producer_ref_count": int(report.get("producer_ref_count", 0)),
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
