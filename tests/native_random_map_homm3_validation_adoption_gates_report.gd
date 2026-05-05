extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_VALIDATION_ADOPTION_GATES_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_validation_adoption_gates_report_v1"
const FEATURE_GATE := "native_rmg_homm3_validation_adoption_gates_10184"
const EXPECTED_CAPABILITIES := [
	"native_random_map_homm3_runtime_zone_graph",
	"native_random_map_homm3_zone_aware_terrain_island_shape",
	"native_random_map_homm3_towns_castles",
	"native_random_map_homm3_roads_rivers_connections",
	"native_random_map_homm3_object_placement_pipeline",
	"native_random_map_homm3_mines_resources",
	"native_random_map_homm3_guards_rewards_monsters",
	"native_random_map_package_session_adoption_bridge",
	"native_package_save_load",
]
const EXPECTED_MINE_CATEGORIES := ["timber", "quicksilver", "ore", "ember_salt", "lens_crystal", "cut_gems", "gold"]
const MEDIUM_OBJECT_BUDGET_MSEC := 20000.0

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

	var capabilities: PackedStringArray = service.get_capabilities()
	for capability in EXPECTED_CAPABILITIES:
		if not capabilities.has(capability):
			_fail("Missing native RMG gate capability %s: %s" % [capability, JSON.stringify(Array(capabilities))])
			return

	var supported_config := ScenarioSelectRulesScript.build_random_map_player_config(
		"native-rmg-homm3-validation-gate-supported-10184",
		"border_gate_compact_v1",
		"border_gate_compact_profile_v1",
		3,
		"land",
		false,
		"homm3_small"
	)
	var medium_config := ScenarioSelectRulesScript.build_random_map_player_config(
		"native-rmg-homm3-validation-gate-medium-10184",
		"translated_rmg_template_005_v1",
		"translated_rmg_profile_005_v1",
		4,
		"land",
		false,
		"homm3_medium"
	)

	var supported: Dictionary = service.generate_random_map(supported_config, {"startup_path": "homm3_validation_gate_supported"})
	var medium: Dictionary = service.generate_random_map(medium_config, {"startup_path": "homm3_validation_gate_medium"})
	var repeat_medium: Dictionary = service.generate_random_map(medium_config.duplicate(true), {"startup_path": "homm3_validation_gate_medium_repeat"})
	var changed_config := medium_config.duplicate(true)
	changed_config["seed"] = "native-rmg-homm3-validation-gate-medium-10184-changed"
	var changed_medium: Dictionary = service.generate_random_map(changed_config, {"startup_path": "homm3_validation_gate_medium_changed"})

	if not _assert_generated_common("supported", supported):
		return
	if not _assert_generated_common("medium", medium):
		return
	if not _assert_generated_common("medium_repeat", repeat_medium):
		return
	var replay_boundary := _assert_replay_boundary(medium, repeat_medium, changed_medium)
	if replay_boundary.is_empty():
		return

	var supported_adoption: Dictionary = service.convert_generated_payload(supported, {
		"feature_gate": FEATURE_GATE,
		"session_save_version": SessionStateStoreScript.SAVE_VERSION,
	})
	var medium_adoption: Dictionary = service.convert_generated_payload(medium, {
		"feature_gate": FEATURE_GATE,
		"session_save_version": SessionStateStoreScript.SAVE_VERSION,
	})
	if not _assert_adoption_boundary("supported", supported_adoption):
		return
	if not _assert_adoption_boundary("medium", medium_adoption):
		return

	var supported_summary := _case_summary(supported, supported_adoption)
	var medium_summary := _case_summary(medium, medium_adoption)
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"validated_gate_surfaces": [
			"template_filtering_and_supported_scope",
			"runtime_zone_graph_connectivity",
			"required_town_and_mine_placements",
			"object_definition_footprint_occupancy_references",
			"road_river_overlay_ranges",
			"guard_reward_monster_semantics",
			"deterministic_replay_identity",
			"performance_budget_summary",
			"package_session_save_replay_boundaries",
		],
		"supported_case": supported_summary,
		"medium_case": medium_summary,
		"replay_boundary": replay_boundary,
		"adoption_status": {
			"supported_profiles": "ready_feature_gated_not_authoritative",
			"translated_medium_profile": "ready_feature_gated_not_authoritative",
			"runtime_call_site_adoption": false,
			"authored_content_writeback": false,
			"save_version_bump": false,
			"alpha_readiness_claim": false,
			"remaining_follow_up": "Authoritative package/session adoption remains gated on runtime call-site adoption and exact full-generation coverage for translated profiles; validated generated components now preserve stable seed/config and full-output replay identity.",
		},
	})])
	get_tree().quit(0)

func _assert_generated_common(case_id: String, generated: Dictionary) -> bool:
	if not bool(generated.get("ok", false)):
		_fail("%s native generation returned ok=false: %s" % [case_id, JSON.stringify(generated)])
		return false
	if String(generated.get("validation_status", "")) != "pass":
		_fail("%s native validation did not pass: %s" % [case_id, JSON.stringify(generated.get("validation_report", {}))])
		return false
	if not bool(generated.get("no_authored_writeback", false)):
		_fail("%s native generation crossed authored writeback boundary." % case_id)
		return false
	if not _assert_template_scope(case_id, generated):
		return false
	if not _assert_runtime_graph(case_id, generated):
		return false
	if not _assert_required_placements(case_id, generated):
		return false
	if not _assert_object_pipeline(case_id, generated):
		return false
	if not _assert_roads_rivers(case_id, generated):
		return false
	if not _assert_guard_reward_semantics(case_id, generated):
		return false
	return true

func _assert_template_scope(case_id: String, generated: Dictionary) -> bool:
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var template_id := String(normalized.get("template_id", ""))
	var profile_id := String(normalized.get("profile_id", ""))
	if template_id == "" or profile_id == "":
		_fail("%s missed normalized template/profile selection: %s" % [case_id, JSON.stringify(normalized)])
		return false
	if case_id == "supported" and String(generated.get("status", "")) != "full_parity_supported":
		_fail("Supported gate case did not remain in supported profile scope: %s" % JSON.stringify(generated.get("provenance", {})))
		return false
	if case_id == "medium" and bool(generated.get("full_parity_claim", false)):
		_fail("Medium translated gate case falsely claimed full parity.")
		return false
	return true

func _assert_runtime_graph(case_id: String, generated: Dictionary) -> bool:
	var zone_layout: Dictionary = generated.get("zone_layout", {}) if generated.get("zone_layout", {}) is Dictionary else {}
	var runtime_graph: Dictionary = zone_layout.get("runtime_zone_graph", {}) if zone_layout.get("runtime_zone_graph", {}) is Dictionary else {}
	var graph_validation: Dictionary = runtime_graph.get("validation", {}) if runtime_graph.get("validation", {}) is Dictionary else {}
	if String(runtime_graph.get("schema_id", "")) != "aurelion_native_rmg_runtime_zone_graph_v1":
		_fail("%s missed runtime zone graph schema: %s" % [case_id, JSON.stringify(runtime_graph)])
		return false
	if String(graph_validation.get("status", "")) != "pass":
		_fail("%s runtime zone graph validation failed: %s" % [case_id, JSON.stringify(graph_validation)])
		return false
	if int(runtime_graph.get("zone_count", 0)) <= 0 or int(runtime_graph.get("link_count", 0)) <= 0:
		_fail("%s runtime graph missed zones or links: %s" % [case_id, JSON.stringify(runtime_graph)])
		return false
	var route_graph: Dictionary = generated.get("route_graph", {}) if generated.get("route_graph", {}) is Dictionary else {}
	var reachability: Dictionary = route_graph.get("required_reachability", {}) if route_graph.get("required_reachability", {}) is Dictionary else {}
	if String(reachability.get("status", "")) != "pass":
		_fail("%s route graph required reachability failed: %s" % [case_id, JSON.stringify(reachability)])
		return false
	return true

func _assert_required_placements(case_id: String, generated: Dictionary) -> bool:
	var town_guard: Dictionary = generated.get("town_guard_placement", {}) if generated.get("town_guard_placement", {}) is Dictionary else {}
	var town: Dictionary = town_guard.get("town_placement", {}) if town_guard.get("town_placement", {}) is Dictionary else {}
	if String(town.get("schema_id", "")) != "aurelion_native_rmg_town_placement_v1":
		_fail("%s missed town placement schema: %s" % [case_id, JSON.stringify(town)])
		return false
	if int(town.get("required_attempt_count", 0)) > int(town.get("placed_required_count", -1)):
		_fail("%s required town/castle placement was not satisfied: %s" % [case_id, JSON.stringify(town)])
		return false
	if int(town.get("town_count", 0)) <= 0:
		_fail("%s did not place any towns." % case_id)
		return false

	var mine_summary: Dictionary = generated.get("mine_resource_summary", {}) if generated.get("mine_resource_summary", {}) is Dictionary else {}
	if String(mine_summary.get("schema_id", "")) != "aurelion_native_rmg_phase7_mines_resources_summary_v1":
		_fail("%s missed mine/resource summary schema: %s" % [case_id, JSON.stringify(mine_summary)])
		return false
	if int(mine_summary.get("required_attempt_count", 0)) > int(mine_summary.get("placed_required_count", -1)):
		_fail("%s required mine/resource placement was not satisfied: %s" % [case_id, JSON.stringify(mine_summary)])
		return false
	for category in EXPECTED_MINE_CATEGORIES:
		if category not in Array(mine_summary.get("category_order", [])):
			_fail("%s mine/resource category order missed %s: %s" % [case_id, category, JSON.stringify(mine_summary)])
			return false
	return true

func _assert_object_pipeline(case_id: String, generated: Dictionary) -> bool:
	var summary: Dictionary = generated.get("object_placement_pipeline_summary", {}) if generated.get("object_placement_pipeline_summary", {}) is Dictionary else {}
	if String(summary.get("schema_id", "")) != "aurelion_native_rmg_homm3_object_placement_pipeline_summary_v1":
		_fail("%s missed object placement pipeline summary: %s" % [case_id, JSON.stringify(summary)])
		return false
	if String(summary.get("validation_status", "")) != "pass":
		_fail("%s object placement pipeline failed validation: %s" % [case_id, JSON.stringify(summary)])
		return false
	for key in ["missing_definition_count", "missing_mask_count", "missing_writeout_count", "body_overlap_count", "limit_failure_count"]:
		if int(summary.get(key, -1)) != 0:
			_fail("%s object pipeline reported %s: %s" % [case_id, key, JSON.stringify(summary)])
			return false
	if int(summary.get("supported_definition_count", 0)) <= 0 or int(summary.get("body_tile_reference_count", 0)) <= 0:
		_fail("%s object pipeline missed definitions or body occupancy: %s" % [case_id, JSON.stringify(summary)])
		return false
	var cost: Dictionary = summary.get("xl_cost", {}) if summary.get("xl_cost", {}) is Dictionary else {}
	if String(cost.get("status", "")) != "pass":
		_fail("%s object placement performance budget did not pass: %s" % [case_id, JSON.stringify(cost)])
		return false
	if case_id == "medium" and float(cost.get("elapsed_msec", 0.0)) > MEDIUM_OBJECT_BUDGET_MSEC:
		_fail("%s object placement exceeded medium gate budget: %s" % [case_id, JSON.stringify(cost)])
		return false
	return true

func _assert_roads_rivers(case_id: String, generated: Dictionary) -> bool:
	var road: Dictionary = generated.get("road_network", {}) if generated.get("road_network", {}) is Dictionary else {}
	var connection: Dictionary = generated.get("connection_payload_resolution", {}) if generated.get("connection_payload_resolution", {}) is Dictionary else {}
	var connection_summary: Dictionary = connection.get("summary", {}) if connection.get("summary", {}) is Dictionary else {}
	if int(connection_summary.get("required_link_failure_count", -1)) != 0:
		_fail("%s required connection corridor failed: %s" % [case_id, JSON.stringify(connection_summary)])
		return false
	if String(road.get("overlay_semantics", "")) != "deterministic_road_overlay_metadata_separate_from_rand_trn_decoration_object_scoring":
		_fail("%s road overlay semantics missing: %s" % [case_id, JSON.stringify(road)])
		return false
	var tile_count := int(generated.get("normalized_config", {}).get("width", 0)) * int(generated.get("normalized_config", {}).get("height", 0))
	var road_tile_count := 0
	for segment in road.get("road_segments", []):
		if segment is Dictionary:
			road_tile_count += int(segment.get("overlay_tile_count", 0))
	if case_id == "medium" and road_tile_count <= 0:
		_fail("%s road overlay tile count did not materialize any road cells." % case_id)
		return false
	if road_tile_count < 0 or road_tile_count > tile_count * 4:
		_fail("%s road overlay tile count out of range: %s / %s" % [case_id, road_tile_count, tile_count])
		return false
	var river: Dictionary = generated.get("river_network", {}) if generated.get("river_network", {}) is Dictionary else {}
	if String(river.get("policy", {}).get("overlay_semantics", "")) != "river_overlay_metadata_separate_from_rand_trn_decoration_object_scoring":
		_fail("%s river overlay semantics missing: %s" % [case_id, JSON.stringify(river)])
		return false
	var river_tile_count := 0
	for segment in river.get("river_segments", []):
		if segment is Dictionary:
			river_tile_count += int(segment.get("overlay_tile_count", 0))
	if river_tile_count < 0 or river_tile_count > tile_count:
		_fail("%s river overlay tile count out of range: %s / %s" % [case_id, river_tile_count, tile_count])
		return false
	return true

func _assert_guard_reward_semantics(case_id: String, generated: Dictionary) -> bool:
	var guard_summary: Dictionary = generated.get("guard_reward_monster_summary", {}) if generated.get("guard_reward_monster_summary", {}) is Dictionary else {}
	if String(guard_summary.get("schema_id", "")) != "aurelion_native_rmg_guards_rewards_monsters_v1":
		_fail("%s missed guard/reward/monster summary: %s" % [case_id, JSON.stringify(guard_summary)])
		return false
	if String(guard_summary.get("validation_status", "")) != "pass":
		_fail("%s guard/reward/monster validation failed: %s" % [case_id, JSON.stringify(guard_summary)])
		return false
	if int(guard_summary.get("guard_count", 0)) <= 0 or int(guard_summary.get("stack_record_count", 0)) < int(guard_summary.get("guard_count", 0)):
		_fail("%s guard records did not materialize original unit stacks: %s" % [case_id, JSON.stringify(guard_summary)])
		return false
	if int(guard_summary.get("stack_mask_mismatch_count", -1)) != 0:
		_fail("%s guard monster masks mismatched: %s" % [case_id, JSON.stringify(guard_summary)])
		return false
	var reward_summary: Dictionary = generated.get("reward_band_summary", {}) if generated.get("reward_band_summary", {}) is Dictionary else {}
	if String(reward_summary.get("schema_id", "")) != "aurelion_native_rmg_phase10_reward_bands_summary_v1":
		_fail("%s missed reward band summary: %s" % [case_id, JSON.stringify(reward_summary)])
		return false
	if int(reward_summary.get("reward_count", 0)) <= 0 or int(reward_summary.get("out_of_band_reward_count", -1)) != 0:
		_fail("%s reward band values failed: %s" % [case_id, JSON.stringify(reward_summary)])
		return false
	return true

func _assert_replay_boundary(first: Dictionary, repeat: Dictionary, changed: Dictionary) -> Dictionary:
	var first_identity := String(first.get("deterministic_identity", {}).get("signature", ""))
	var repeat_identity := String(repeat.get("deterministic_identity", {}).get("signature", ""))
	var changed_identity := String(changed.get("deterministic_identity", {}).get("signature", ""))
	if first_identity == "" or first_identity != repeat_identity:
		_fail("Same seed/config did not preserve deterministic config identity: %s vs %s" % [first_identity, repeat_identity])
		return {}
	if first_identity == changed_identity:
		_fail("Changed seed did not change deterministic config identity: %s" % first_identity)
		return {}
	var first_signature := String(first.get("full_output_signature", ""))
	var repeat_signature := String(repeat.get("full_output_signature", ""))
	var changed_signature := String(changed.get("full_output_signature", ""))
	if first_signature == "" or first_signature != repeat_signature:
		_fail("Same seed/config did not preserve full output signature: %s vs %s; component_diff=%s; object_diff=%s" % [
			first_signature,
			repeat_signature,
			JSON.stringify(_signature_diff(
				first.get("component_signatures", {}) if first.get("component_signatures", {}) is Dictionary else {},
				repeat.get("component_signatures", {}) if repeat.get("component_signatures", {}) is Dictionary else {}
			)),
			JSON.stringify(_record_signature_diff(
				first.get("object_placements", []) if first.get("object_placements", []) is Array else [],
				repeat.get("object_placements", []) if repeat.get("object_placements", []) is Array else [],
				"placement_id"
			)),
		])
		return {}
	if first_signature == changed_signature:
		_fail("Changed seed did not change full output signature: %s" % first_signature)
		return {}
	return {
		"deterministic_config_identity_stable": true,
		"changed_seed_identity_changes": true,
		"full_output_signature_stable": true,
		"first_full_output_signature": first_signature,
		"repeat_full_output_signature": repeat_signature,
		"changed_full_output_signature": changed_signature,
		"policy": "seed_config_and_full_output_replay_boundary_stable_for_validated_components",
	}

func _signature_diff(first: Dictionary, repeat: Dictionary) -> Dictionary:
	var keys := {}
	for key in first.keys():
		keys[String(key)] = true
	for key in repeat.keys():
		keys[String(key)] = true
	var result := {}
	for key in keys.keys():
		var first_value := String(first.get(key, ""))
		var repeat_value := String(repeat.get(key, ""))
		if first_value != repeat_value:
			result[key] = {
				"first": first_value,
				"repeat": repeat_value,
			}
	return result

func _record_signature_diff(first: Array, repeat: Array, id_key: String) -> Array:
	var repeat_by_id := {}
	for record in repeat:
		if record is Dictionary:
			repeat_by_id[String(record.get(id_key, ""))] = record
	var result := []
	for record in first:
		if not (record is Dictionary):
			continue
		var record_id := String(record.get(id_key, ""))
		var other: Dictionary = repeat_by_id.get(record_id, {}) if repeat_by_id.get(record_id, {}) is Dictionary else {}
		if other.is_empty():
			result.append({"id": record_id, "issue": "missing_in_repeat"})
		elif String(record.get("signature", "")) != String(other.get("signature", "")):
			result.append({
				"id": record_id,
				"first_signature": String(record.get("signature", "")),
				"repeat_signature": String(other.get("signature", "")),
				"first": _brief_record(record),
				"repeat": _brief_record(other),
			})
		if result.size() >= 5:
			return result
	return result

func _brief_record(record: Dictionary) -> Dictionary:
	return {
		"kind": String(record.get("kind", record.get("guard_kind", ""))),
		"zone_id": String(record.get("zone_id", "")),
		"x": int(record.get("x", 0)),
		"y": int(record.get("y", 0)),
		"family_id": String(record.get("family_id", "")),
		"object_id": String(record.get("object_id", "")),
		"category_id": String(record.get("category_id", "")),
	}

func _assert_adoption_boundary(case_id: String, adoption: Dictionary) -> bool:
	if not bool(adoption.get("ok", false)) or String(adoption.get("status", "")) != "pass":
		_fail("%s package/session conversion failed: %s" % [case_id, JSON.stringify(adoption)])
		return false
	var report: Dictionary = adoption.get("report", {}) if adoption.get("report", {}) is Dictionary else {}
	if String(report.get("schema_id", "")) != "aurelion_native_random_map_package_session_adoption_report_v1":
		_fail("%s adoption report schema mismatch: %s" % [case_id, JSON.stringify(report)])
		return false
	if not bool(report.get("package_session_adoption_ready", false)):
		_fail("%s package/session bridge was not ready: %s" % [case_id, JSON.stringify(report)])
		return false
	if bool(report.get("runtime_call_site_adoption", true)) or bool(adoption.get("authored_content_writeback", true)) or bool(adoption.get("save_version_bump", true)):
		_fail("%s adoption crossed runtime/writeback/save boundaries: %s" % [case_id, JSON.stringify(adoption)])
		return false
	var boundary: Dictionary = adoption.get("session_boundary_record", {}) if adoption.get("session_boundary_record", {}) is Dictionary else {}
	if String(boundary.get("feature_gate", "")) != FEATURE_GATE or bool(boundary.get("runtime_call_site_adoption", true)):
		_fail("%s session boundary did not preserve feature gate: %s" % [case_id, JSON.stringify(boundary)])
		return false
	if bool(report.get("native_runtime_authoritative", true)) or bool(report.get("full_parity_claim", true)):
		_fail("%s adoption should remain feature-gated and non-authoritative: %s" % [case_id, JSON.stringify(report)])
		return false
	if String(report.get("adoption_status", "")) != "ready_feature_gated_not_authoritative":
		_fail("%s adoption status should remain non-authoritative: %s" % [case_id, JSON.stringify(report)])
		return false
	var guard_adoption: Dictionary = report.get("guard_reward_package_adoption", {}) if report.get("guard_reward_package_adoption", {}) is Dictionary else {}
	if String(guard_adoption.get("status", "")) != "pass":
		_fail("%s guard/reward package adoption summary failed: %s" % [case_id, JSON.stringify(guard_adoption)])
		return false
	return true

func _case_summary(generated: Dictionary, adoption: Dictionary) -> Dictionary:
	var object_cost: Dictionary = generated.get("object_placement_pipeline_summary", {}).get("xl_cost", {}) if generated.get("object_placement_pipeline_summary", {}) is Dictionary else {}
	var report: Dictionary = adoption.get("report", {}) if adoption.get("report", {}) is Dictionary else {}
	return {
		"status": generated.get("status", ""),
		"full_generation_status": generated.get("full_generation_status", ""),
		"template_id": generated.get("normalized_config", {}).get("template_id", ""),
		"profile_id": generated.get("normalized_config", {}).get("profile_id", ""),
		"full_output_signature": generated.get("full_output_signature", ""),
		"zone_count": generated.get("zone_layout", {}).get("runtime_zone_graph", {}).get("zone_count", 0),
		"link_count": generated.get("zone_layout", {}).get("runtime_zone_graph", {}).get("link_count", 0),
		"town_count": generated.get("town_guard_placement", {}).get("town_count", 0),
		"object_count": generated.get("object_placement", {}).get("object_count", 0),
		"guard_count": generated.get("guard_reward_monster_summary", {}).get("guard_count", 0),
		"reward_count": generated.get("reward_band_summary", {}).get("reward_count", 0),
		"object_elapsed_msec": object_cost.get("elapsed_msec", 0.0),
		"performance_budget_msec": MEDIUM_OBJECT_BUDGET_MSEC,
		"package_session_adoption_ready": report.get("package_session_adoption_ready", false),
		"native_runtime_authoritative": report.get("native_runtime_authoritative", false),
		"runtime_call_site_adoption": report.get("runtime_call_site_adoption", true),
		"full_parity_claim": report.get("full_parity_claim", false),
		"adoption_status": report.get("adoption_status", ""),
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
