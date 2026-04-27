extends Node

const AnimationCueCatalogScript = preload("res://scripts/core/AnimationCueCatalog.gd")
const REPORT_ID := "ANIMATION_BATTLE_TROOP_STATE_CONTRACT_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report := AnimationCueCatalogScript.battle_troop_sprite_state_contract_report()
	if not bool(report.get("ok", false)):
		_fail("Battle troop sprite state contract failed: %s" % report)
		return
	if String(report.get("schema_id", "")) != "battle_troop_sprite_state_contract_v1":
		_fail("Unexpected battle troop state contract schema: %s" % report)
		return

	var state_family_counts: Dictionary = report.get("state_family_counts", {}) if report.get("state_family_counts", {}) is Dictionary else {}
	for family in ["idle", "ready", "move", "attack", "hit", "death", "cast", "status", "defend", "retreat"]:
		if int(state_family_counts.get(family, 0)) <= 0:
			_fail("Missing battle troop state family %s: %s" % [family, report])
			return

	var representative_events: Dictionary = report.get("representative_events", {}) if report.get("representative_events", {}) is Dictionary else {}
	var expected_events := {
		"idle": "battle_stack_idle",
		"ready": "battle_stack_ready",
		"move": "battle_unit_move",
		"attack": "battle_unit_melee_attack",
		"hit": "battle_unit_hit",
		"death": "battle_unit_death",
		"cast": "battle_unit_cast",
		"status": "battle_status_applied",
		"defend": "battle_unit_defend",
		"retreat": "battle_unit_retreat",
	}
	for family in expected_events.keys():
		if String(representative_events.get(family, "")) != String(expected_events[family]):
			_fail("Representative event mismatch for %s: %s" % [family, report])
			return

	var fallback_counts: Dictionary = report.get("fallback_counts", {}) if report.get("fallback_counts", {}) is Dictionary else {}
	var battle_troop_entry_count := int(report.get("battle_troop_entry_count", 0))
	if battle_troop_entry_count < expected_events.size():
		_fail("Battle troop entry coverage is too small: %s" % report)
		return
	if int(fallback_counts.get("reduced_motion", 0)) != battle_troop_entry_count:
		_fail("Battle troop reduced-motion fallback coverage is incomplete: %s" % report)
		return
	if int(fallback_counts.get("fast_mode", 0)) != battle_troop_entry_count:
		_fail("Battle troop fast-mode fallback coverage is incomplete: %s" % report)
		return
	if int(report.get("producer_ref_count", 0)) < expected_events.size():
		_fail("Battle troop producer refs are incomplete: %s" % report)
		return

	var policy_cases: Dictionary = report.get("policy_cases", {}) if report.get("policy_cases", {}) is Dictionary else {}
	var retreat_policy: Dictionary = policy_cases.get("battle_unit_retreat", {}) if policy_cases.get("battle_unit_retreat", {}) is Dictionary else {}
	var retreat_reduced: Dictionary = retreat_policy.get("reduced_motion", {}) if retreat_policy.get("reduced_motion", {}) is Dictionary else {}
	var retreat_fast: Dictionary = retreat_policy.get("fast", {}) if retreat_policy.get("fast", {}) is Dictionary else {}
	var retreat_combined: Dictionary = retreat_policy.get("reduced_motion_fast", {}) if retreat_policy.get("reduced_motion_fast", {}) is Dictionary else {}
	if String(retreat_reduced.get("selected_fallback_tag", "")) != "withdraw_icon_static":
		_fail("Retreat reduced-motion fallback was not selected: %s" % retreat_policy)
		return
	if String(retreat_fast.get("selected_fallback_tag", "")) != "withdraw_icon_flash" or String(retreat_fast.get("selected_playback_policy", "")) != "fast_resolve":
		_fail("Retreat fast-mode fallback was not selected: %s" % retreat_policy)
		return
	if String(retreat_combined.get("selected_fallback_tag", "")) != "withdraw_icon_static" or String(retreat_combined.get("timing_preference", "")) != "fast":
		_fail("Retreat combined policy did not use reduced visuals with fast timing: %s" % retreat_policy)
		return

	var idle_policy: Dictionary = policy_cases.get("battle_stack_idle", {}) if policy_cases.get("battle_stack_idle", {}) is Dictionary else {}
	var idle_normal: Dictionary = idle_policy.get("normal", {}) if idle_policy.get("normal", {}) is Dictionary else {}
	if String(idle_normal.get("selected_animation_state", "")) != "idle_hold":
		_fail("Idle normal policy did not keep the authored idle state: %s" % idle_policy)
		return
	if not _assert_public_payload("battle troop state public payload", report.get("public_payload", {})):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_id": String(report.get("schema_id", "")),
		"schema_status": String(report.get("schema_status", "")),
		"battle_troop_entry_count": battle_troop_entry_count,
		"state_family_counts": state_family_counts,
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
