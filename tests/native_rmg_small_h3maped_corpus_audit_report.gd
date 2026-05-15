extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RMG_SMALL_H3MAPED_CORPUS_AUDIT_REPORT"
const REPORT_SCHEMA_ID := "native_rmg_small_h3maped_corpus_audit_report_v1"

const SEEDS := ["1", "2", "3", "4", "5"]
const PLAYER_COUNTS := [2, 3, 4]
const OWNER_H3M_EVIDENCE_PATHS := [
	"res://maps/small3playermap-1level.h3m",
	"res://maps/small3playermap.h3m",
]

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
	var missing_evidence := []
	for evidence_path in OWNER_H3M_EVIDENCE_PATHS:
		if not FileAccess.file_exists(String(evidence_path)):
			missing_evidence.append(evidence_path)
	if not missing_evidence.is_empty():
		_fail("Small H3M evidence files are missing: %s" % JSON.stringify(missing_evidence))
		return

	var cases := []
	var failures := []
	var aggregate := {
		"case_count": 0,
		"package_object_count": 0,
		"town_count": 0,
		"mine_count": 0,
		"reward_count": 0,
		"connection_blocker_count": 0,
		"connection_guard_count": 0,
		"decorative_obstacle_count": 0,
		"route_link_count": 0,
		"guarded_route_link_count": 0,
		"road_record_count": 0,
		"road_segment_cell_total": 0,
		"road_overlay_type_nonzero_count": 0,
	}
	var templates := {}
	for player_count in PLAYER_COUNTS:
		for seed in SEEDS:
			var summary := _run_case(service, String(seed), int(player_count))
			cases.append(summary)
			aggregate["case_count"] = int(aggregate["case_count"]) + 1
			for key in aggregate.keys():
				if key == "case_count":
					continue
				aggregate[key] = int(aggregate.get(key, 0)) + int(summary.get(key, 0))
			templates[String(summary.get("source_template_id", ""))] = true
			if not bool(summary.get("ok", false)):
				failures.append(summary)

	if not failures.is_empty():
		_fail("Small h3maped corpus audit failed: %s" % JSON.stringify({
			"failures": failures,
			"cases": cases,
			"aggregate": aggregate,
		}))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"case_count": cases.size(),
		"seed_count": SEEDS.size(),
		"player_counts": PLAYER_COUNTS,
		"source_template_ids": templates.keys(),
		"aggregate": aggregate,
		"cases": cases,
		"owner_h3m_evidence_paths": OWNER_H3M_EVIDENCE_PATHS,
		"comparison_policy": "structural_small_land_corpus_gate_no_uploaded_count_fitting",
		"remaining_gap": "Focused Slice G corpus coverage checks supported Small land seeds/player counts for native validator, source-state, roads, blockers, guards, mines, rewards, decorative blockers, save/load identity, and explicit template authority. Production readiness is scoped only to strict Small 36x36 one-level land; full parity, water/underground/larger-size support, and broad template support remain blocked.",
	})])
	get_tree().quit(0)

func _run_case(service: Variant, seed: String, player_count: int) -> Dictionary:
	var case_id := "small_land_p%d_seed_%s" % [player_count, seed]
	var config := ScenarioSelectRulesScript.build_random_map_player_config(seed, "", "", player_count, "land", false, "homm3_small")
	var report: Dictionary = service.inspect_h3maped_small_rmg_port(config)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "small_h3maped_corpus_audit"})
	var summary := {
		"id": case_id,
		"ok": false,
		"seed": seed,
		"player_count": player_count,
		"failures": [],
	}
	var failures: Array = summary["failures"]
	if not bool(report.get("ok", false)):
		failures.append("inspect_port_not_ok")
	if not bool(generated.get("ok", false)):
		failures.append("generate_random_map_not_ok")
	if String(generated.get("status", "")) != "h3maped_small_validated_package_ready":
		failures.append("generation_status_not_validated_package_ready")
	var generated_cell_bit_state: Dictionary = report.get("generated_cell_decoration_bit_state", {}) if report.get("generated_cell_decoration_bit_state", {}) is Dictionary else {}
	if not bool(generated_cell_bit_state.get("exact_upstream_bit_source_claim", false)):
		failures.append("exact_upstream_bit_source_claim_not_true")
	if int(generated_cell_bit_state.get("owner_transition_diagnostic_new_gap_count", -1)) != 0:
		failures.append("owner_transition_diagnostic_gap_nonzero")
	var package_adoption: Dictionary = report.get("public_package_adoption", {}) if report.get("public_package_adoption", {}) is Dictionary else {}
	if String(package_adoption.get("status", "")) != "strict_package_adoption_draft_materialized_runtime_blocked":
		failures.append("package_adoption_status_not_materialized")
	var town_castle: Dictionary = report.get("town_castle_phase", {}) if report.get("town_castle_phase", {}) is Dictionary else {}
	var scheduled_owned_towns := int(town_castle.get("scheduled_owned_player_town_count", 0))
	var scheduled_neutral_minimum_towns := int(town_castle.get("scheduled_neutral_minimum_town_count", 0))
	var scheduled_inactive_neutralized_towns := int(town_castle.get("scheduled_inactive_player_neutralized_town_count", 0))
	var expected_town_count := scheduled_owned_towns + scheduled_neutral_minimum_towns + scheduled_inactive_neutralized_towns
	var expected_neutral_town_count := scheduled_neutral_minimum_towns + scheduled_inactive_neutralized_towns
	var final_writeout: Dictionary = report.get("final_h3m_writeout", {}) if report.get("final_h3m_writeout", {}) is Dictionary else {}
	if String(final_writeout.get("status", "")) != "strict_final_0x49b2b6_writeout_draft_runtime_blocked":
		failures.append("final_writeout_status_not_ready")
	var validator: Dictionary = generated.get("fast_structural_validator", {}) if generated.get("fast_structural_validator", {}) is Dictionary else {}
	var metrics: Dictionary = validator.get("metrics", {}) if validator.get("metrics", {}) is Dictionary else {}
	if String(validator.get("status", "")) != "strict_fast_structural_validator_pass_public_generation_ready" or int(validator.get("failure_count", -1)) != 0:
		failures.append("fast_structural_validator_not_green")
	_check_metric(metrics, "expected_tile_count", 1296, failures)
	_check_metric(metrics, "terrain_tile_count", 1296, failures)
	_check_metric(metrics, "player_start_count", player_count, failures)
	_check_metric(metrics, "owned_player_town_count", player_count, failures)
	_check_metric(metrics, "unguarded_route_link_count", 0, failures)
	_check_metric(metrics, "route_link_without_blocker_count", 0, failures)
	_check_metric(metrics, "route_link_without_guard_count", 0, failures)
	_check_metric(metrics, "road_segment_disconnected_count", 0, failures)
	_check_metric(metrics, "road_segment_without_route_edge_count", 0, failures)
	_check_metric(metrics, "road_segment_missing_metadata_count", 0, failures)
	_check_metric(metrics, "road_segment_short_loop_count", 0, failures)
	_check_metric(metrics, "duplicate_placement_id_count", 0, failures)
	_check_metric(metrics, "out_of_bounds_object_count", 0, failures)
	if int(metrics.get("town_count", 0)) < player_count:
		failures.append("town_count_below_player_count")
	if expected_town_count > 0 and int(metrics.get("town_count", 0)) != expected_town_count:
		failures.append("town_count_expected_h3maped_scheduled_%d_got_%d" % [expected_town_count, int(metrics.get("town_count", 0))])
	if int(metrics.get("neutral_town_count", 0)) != expected_neutral_town_count:
		failures.append("neutral_town_count_expected_h3maped_scheduled_%d_got_%d" % [expected_neutral_town_count, int(metrics.get("neutral_town_count", 0))])
	if expected_neutral_town_count > 0 and int(metrics.get("town_count", 0)) <= player_count:
		failures.append("inactive_or_neutral_source_towns_not_materialized")
	if int(metrics.get("mine_count", 0)) <= 0:
		failures.append("mine_count_missing")
	if int(metrics.get("reward_count", 0)) <= 0:
		failures.append("reward_count_missing")
	if int(metrics.get("connection_blocker_count", 0)) <= 0 or int(metrics.get("blocking_connection_blocker_count", 0)) != int(metrics.get("connection_blocker_count", -1)):
		failures.append("connection_blockers_missing_or_not_blocking")
	if int(metrics.get("connection_guard_count", 0)) <= 0 or int(metrics.get("blocking_connection_guard_count", 0)) != int(metrics.get("connection_guard_count", -1)):
		failures.append("connection_guards_missing_or_not_blocking")
	if int(metrics.get("route_link_count", 0)) <= 0 or int(metrics.get("guarded_route_link_count", -1)) != int(metrics.get("route_link_count", 0)):
		failures.append("route_links_missing_or_not_guarded")
	if int(metrics.get("road_record_count", 0)) <= 0 or int(metrics.get("road_route_edge_count", -1)) != int(metrics.get("road_record_count", 0)):
		failures.append("roads_missing_or_not_route_attached")
	if int(metrics.get("road_route_node_count", 0)) < player_count:
		failures.append("road_route_node_count_below_player_count")
	if int(metrics.get("road_overlay_type_nonzero_count", 0)) <= 0:
		failures.append("road_overlay_missing")
	if int(package_adoption.get("decorative_obstacle_package_object_count", 0)) <= 0:
		failures.append("decorative_obstacle_package_count_missing")
	if String(generated.get("full_generation_status", "")) != "h3maped_small_public_package_production_ready_strict_small_land" \
			or not bool(generated.get("production_ready", false)) \
			or String(generated.get("production_ready_scope", "")) != "strict_small_36x36_one_level_land_only":
		failures.append("production_status_contract_drifted")

	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_small_h3maped_corpus_audit",
		"session_save_version": 9,
		"scenario_id": "native_small_h3maped_corpus_%s" % case_id,
	})
	if not bool(adoption.get("ok", false)):
		failures.append("convert_generated_payload_failed")
	else:
		var map_document: Variant = adoption.get("map_document", null)
		if map_document == null:
			failures.append("adoption_missing_map_document")
		else:
			var map_path := "user://native_small_h3maped_corpus_%s.amap" % case_id
			var save_result: Dictionary = service.save_map_package(map_document, map_path)
			if not bool(save_result.get("ok", false)):
				failures.append("save_map_package_failed")
			else:
				var load_result: Dictionary = service.load_map_package(map_path)
				DirAccess.remove_absolute(map_path)
				if not bool(load_result.get("ok", false)):
					failures.append("load_map_package_failed")
				else:
					var loaded_document: Variant = load_result.get("map_document", null)
					if loaded_document == null:
						failures.append("load_missing_map_document")
					elif int(loaded_document.get_object_count()) != int(metrics.get("package_object_count", -1)):
						failures.append("save_load_object_count_mismatch")

	summary["ok"] = failures.is_empty()
	summary["source_template_id"] = _source_template_id(report, generated)
	summary["source_template_authority"] = _source_template_authority(generated)
	summary["package_object_count"] = int(metrics.get("package_object_count", 0))
	summary["town_count"] = int(metrics.get("town_count", 0))
	summary["neutral_town_count"] = int(metrics.get("neutral_town_count", 0))
	summary["h3maped_scheduled_town_count"] = expected_town_count
	summary["h3maped_scheduled_neutral_town_count"] = expected_neutral_town_count
	summary["mine_count"] = int(metrics.get("mine_count", 0))
	summary["reward_count"] = int(metrics.get("reward_count", 0))
	summary["connection_blocker_count"] = int(metrics.get("connection_blocker_count", 0))
	summary["connection_guard_count"] = int(metrics.get("connection_guard_count", 0))
	summary["decorative_obstacle_count"] = int(package_adoption.get("decorative_obstacle_package_object_count", 0))
	summary["route_link_count"] = int(metrics.get("route_link_count", 0))
	summary["guarded_route_link_count"] = int(metrics.get("guarded_route_link_count", 0))
	summary["road_record_count"] = int(metrics.get("road_record_count", 0))
	summary["road_segment_cell_total"] = int(metrics.get("road_segment_cell_total", 0))
	summary["road_overlay_type_nonzero_count"] = int(metrics.get("road_overlay_type_nonzero_count", 0))
	summary["owner_transition_diagnostic_new_gap_count"] = int(generated_cell_bit_state.get("owner_transition_diagnostic_new_gap_count", -1))
	summary["exact_upstream_bit_source_claim"] = bool(generated_cell_bit_state.get("exact_upstream_bit_source_claim", false))
	summary["validator_status"] = String(validator.get("status", ""))
	return summary

func _check_metric(metrics: Dictionary, key: String, expected: int, failures: Array) -> void:
	if int(metrics.get(key, -999999)) != expected:
		failures.append("%s_expected_%d_got_%d" % [key, expected, int(metrics.get(key, -999999))])

func _source_template_id(report: Dictionary, generated: Dictionary) -> String:
	var map_payload: Dictionary = generated.get("map_document_payload", {}) if generated.get("map_document_payload", {}) is Dictionary else {}
	if not String(map_payload.get("source_template_id", "")).is_empty():
		return String(map_payload.get("source_template_id", ""))
	var selection: Dictionary = report.get("selection_identity", {}) if report.get("selection_identity", {}) is Dictionary else {}
	return String(selection.get("source_template_id", ""))

func _source_template_authority(generated: Dictionary) -> String:
	var map_payload: Dictionary = generated.get("map_document_payload", {}) if generated.get("map_document_payload", {}) is Dictionary else {}
	return String(map_payload.get("source_template_authority", ""))

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": false,
		"error": message,
	})])
	get_tree().quit(1)
