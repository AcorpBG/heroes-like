class_name NativeRandomMapPackageSessionBridge
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

static func build_session_from_adoption(
	adoption: Dictionary,
	difficulty: String = "normal",
	options: Dictionary = {}
) -> SessionStateStoreScript.SessionData:
	if not bool(adoption.get("ok", false)):
		return SessionStateStoreScript.new_session_data()
	var boundary: Dictionary = adoption.get("session_boundary_record", {}) if adoption.get("session_boundary_record", {}) is Dictionary else {}
	if boundary.is_empty():
		return SessionStateStoreScript.new_session_data()

	var scenario_id := String(boundary.get("scenario_id", ""))
	var session_id := String(boundary.get("session_id", ""))
	var hero_id := String(boundary.get("hero_id", options.get("hero_id", "hero_lyra")))
	var map_ref: Dictionary = boundary.get("map_package_ref", {}) if boundary.get("map_package_ref", {}) is Dictionary else {}
	var scenario_ref: Dictionary = boundary.get("scenario_package_ref", {}) if boundary.get("scenario_package_ref", {}) is Dictionary else {}
	var report: Dictionary = adoption.get("report", {}) if adoption.get("report", {}) is Dictionary else {}
	var metrics: Dictionary = report.get("metrics", {}) if report.get("metrics", {}) is Dictionary else {}
	var start := _primary_start(adoption)
	var overworld_state := {
		"map": [],
		"map_size": {
			"width": int(metrics.get("width", 0)),
			"height": int(metrics.get("height", 0)),
			"x": int(metrics.get("width", 0)),
			"y": int(metrics.get("height", 0)),
			"level_count": int(metrics.get("level_count", 1)),
		},
		"terrain_layers": {},
		"active_hero_id": hero_id,
		"player_heroes": [],
		"hero_position": start,
		"movement": {"current": 0, "max": 0},
		"resources": {},
		"encounters": [],
		"resolved_encounters": [],
		"towns": [],
		"resource_nodes": [],
		"artifact_nodes": [],
		"map_package_ref": map_ref,
		"scenario_package_ref": scenario_ref,
		"native_random_map_package_session_adoption": boundary.duplicate(true),
		"generated_random_map_identity": adoption.get("generated_identity", {}),
		"generated_random_map_validation": adoption.get("validation_report", {}),
	}
	var session := SessionStateStoreScript.new_session_data(
		session_id,
		scenario_id,
		hero_id,
		1,
		overworld_state,
		difficulty,
		SessionStateStoreScript.LAUNCH_MODE_GENERATED_DRAFT
	)
	session.save_version = SessionStateStoreScript.SAVE_VERSION
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
	session.flags = {
		"native_random_map_package_session_adoption": true,
		"native_random_map_feature_gate": String(boundary.get("feature_gate", "")),
		"generated_random_map": true,
		"generated_random_map_source": "native_rmg_package_session_bridge",
		"generated_random_map_boundary": {
			"authored_content_writeback": false,
			"campaign_adoption": false,
			"skirmish_browser_authored_listing": false,
			"runtime_call_site_adoption": false,
			"native_runtime_authoritative": false,
			"full_parity_claim": false,
			"adoption_path": "native_rmg_package_session_bridge_feature_gated",
		},
		"map_package_ref": map_ref,
		"scenario_package_ref": scenario_ref,
		"generated_random_map_provenance": adoption.get("provenance", {}),
		"generated_random_map_validation": adoption.get("validation_report", {}),
	}
	return session

static func _primary_start(adoption: Dictionary) -> Dictionary:
	var scenario_document: Variant = adoption.get("scenario_document", null)
	if scenario_document != null and scenario_document.has_method("get_start_contract"):
		var start_contract: Dictionary = scenario_document.get_start_contract()
		var starts: Array = start_contract.get("player_starts", []) if start_contract.get("player_starts", []) is Array else []
		if not starts.is_empty() and starts[0] is Dictionary:
			return {"x": int(starts[0].get("x", 0)), "y": int(starts[0].get("y", 0))}
	return {"x": 0, "y": 0}
