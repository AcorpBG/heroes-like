extends Node

const REPORT_ID := "NATIVE_RMG_SMALL_H3MAPED_PUBLIC_TEMPLATE_MATRIX_REPORT"
const REPORT_SCHEMA_ID := "native_rmg_small_h3maped_public_template_matrix_report_v1"

const EXPECTED_2P_3P_TEMPLATES := [
	"h3maped_template_000",
	"h3maped_template_012",
	"h3maped_template_018",
	"h3maped_template_020",
	"h3maped_template_022",
	"h3maped_template_024",
	"h3maped_template_027",
	"h3maped_template_028",
	"h3maped_template_031",
	"h3maped_template_044",
	"h3maped_template_046",
	"h3maped_template_047",
	"h3maped_template_048",
]
const EXPECTED_3P_TEMPLATES := [
	"h3maped_template_000",
	"h3maped_template_012",
	"h3maped_template_018",
	"h3maped_template_020",
	"h3maped_template_024",
	"h3maped_template_027",
	"h3maped_template_028",
	"h3maped_template_031",
	"h3maped_template_044",
	"h3maped_template_046",
	"h3maped_template_047",
	"h3maped_template_048",
]
const EXPECTED_4P_TEMPLATES := [
	"h3maped_template_000",
	"h3maped_template_012",
	"h3maped_template_018",
	"h3maped_template_020",
	"h3maped_template_024",
	"h3maped_template_027",
	"h3maped_template_028",
	"h3maped_template_031",
	"h3maped_template_046",
	"h3maped_template_047",
	"h3maped_template_048",
]
const SEEDS_FOR_13_ACCEPTED := ["28", "92", "1", "9", "73", "137", "2", "58", "122", "3", "43", "107", "4"]
const SEEDS_FOR_12_ACCEPTED := ["3", "7", "11", "4", "8", "1", "5", "20", "9", "2", "6", "10"]
const SEEDS_FOR_11_ACCEPTED := ["12", "2", "9", "6", "3", "10", "7", "4", "1", "8", "5"]
const EXACT_REGRESSION_SEED := "1270881600"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.", {})
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var metadata: Dictionary = service.get_api_metadata()
	if String(metadata.get("binding_kind", "")) != "native_gdextension" or not bool(metadata.get("native_extension_loaded", false)):
		_fail("Native GDExtension metadata did not prove native load.", metadata)
		return

	var cases := []
	var failures := []
	var seen_by_player_count := {2: {}, 3: {}, 4: {}}
	var exact := _run_case(service, EXACT_REGRESSION_SEED, 2, "exact_failed_seed_1270881600")
	cases.append(exact)
	if not bool(exact.get("ok", false)) or String(exact.get("source_template_id", "")) != "h3maped_template_012":
		failures.append(exact)

	for seed in SEEDS_FOR_13_ACCEPTED:
		var summary_2p := _run_case(service, String(seed), 2, "matrix_2p_seed_%s" % seed)
		cases.append(summary_2p)
		seen_by_player_count[2][String(summary_2p.get("source_template_id", ""))] = true
		if not bool(summary_2p.get("ok", false)):
			failures.append(summary_2p)
	for seed in SEEDS_FOR_12_ACCEPTED:
		var summary_3p := _run_case(service, String(seed), 3, "matrix_3p_seed_%s" % seed)
		cases.append(summary_3p)
		seen_by_player_count[3][String(summary_3p.get("source_template_id", ""))] = true
		if not bool(summary_3p.get("ok", false)):
			failures.append(summary_3p)
	for seed in SEEDS_FOR_11_ACCEPTED:
		var summary := _run_case(service, String(seed), 4, "matrix_4p_seed_%s" % seed)
		cases.append(summary)
		seen_by_player_count[4][String(summary.get("source_template_id", ""))] = true
		if not bool(summary.get("ok", false)):
			failures.append(summary)

	_check_template_coverage(2, EXPECTED_2P_3P_TEMPLATES, seen_by_player_count[2], failures)
	_check_template_coverage(3, EXPECTED_3P_TEMPLATES, seen_by_player_count[3], failures)
	_check_template_coverage(4, EXPECTED_4P_TEMPLATES, seen_by_player_count[4], failures)
	if not failures.is_empty():
		_fail("Public Small-land template matrix failed.", {
			"failures": failures,
			"seen_by_player_count": seen_by_player_count,
			"case_count": cases.size(),
		})
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"case_count": cases.size(),
		"exact_regression_seed": EXACT_REGRESSION_SEED,
		"seen_by_player_count": seen_by_player_count,
		"cases": cases,
	})])
	get_tree().quit(0)

func _run_case(service: Variant, seed: String, player_count: int, case_id: String) -> Dictionary:
	var config := {
		"seed": seed,
		"size": {
			"width": 36,
			"height": 36,
			"level_count": 1,
			"water_mode": "land",
			"size_class_id": "homm3_small",
		},
		"player_constraints": {
			"human_count": 1,
			"player_count": player_count,
			"team_mode": "free_for_all",
		},
	}
	var identity: Dictionary = service.random_map_config_identity(config)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "public_template_matrix"})
	var validator: Dictionary = generated.get("fast_structural_validator", {}) if generated.get("fast_structural_validator", {}) is Dictionary else {}
	var metrics: Dictionary = validator.get("metrics", {}) if validator.get("metrics", {}) is Dictionary else {}
	var failures := []
	if not bool(identity.get("ok", false)):
		failures.append("identity_not_ok")
	if not bool(generated.get("ok", false)):
		failures.append("generate_random_map_not_ok")
	if String(generated.get("status", "")) != "h3maped_small_validated_package_ready":
		failures.append("generation_status_not_validated_package_ready")
	if String(validator.get("status", "")) != "strict_fast_structural_validator_pass_public_generation_ready" or int(validator.get("failure_count", -1)) != 0:
		failures.append("fast_structural_validator_not_green")
	_check_metric(metrics, "route_link_without_blocker_count", 0, failures)
	_check_metric(metrics, "route_link_without_guard_count", 0, failures)
	_check_metric(metrics, "unguarded_route_link_count", 0, failures)
	_check_metric(metrics, "road_segment_disconnected_count", 0, failures)
	_check_metric(metrics, "road_segment_without_route_edge_count", 0, failures)
	_check_metric(metrics, "road_segment_missing_metadata_count", 0, failures)
	_check_metric(metrics, "road_segment_short_loop_count", 0, failures)
	_check_metric(metrics, "duplicate_placement_id_count", 0, failures)
	_check_metric(metrics, "out_of_bounds_object_count", 0, failures)
	if int(metrics.get("route_link_count", 0)) <= 0:
		failures.append("route_link_count_missing")
	if int(metrics.get("connection_blocker_count", 0)) <= 0:
		failures.append("connection_blockers_missing")
	if int(metrics.get("connection_guard_count", 0)) <= 0:
		failures.append("connection_guards_missing")
	if int(metrics.get("owned_player_town_count", 0)) != player_count:
		failures.append("owned_player_town_count_mismatch")
	if int(metrics.get("town_count", 0)) < player_count:
		failures.append("town_count_below_player_count")
	if int(metrics.get("mine_count", 0)) <= 0:
		failures.append("mine_count_missing")
	if int(metrics.get("reward_count", 0)) <= 0:
		failures.append("reward_count_missing")

	var normalized: Dictionary = identity.get("normalized_config", {}) if identity.get("normalized_config", {}) is Dictionary else {}
	return {
		"ok": failures.is_empty(),
		"case_id": case_id,
		"seed": seed,
		"player_count": player_count,
		"source_template_id": String(generated.get("source_template_id", normalized.get("template_id", ""))),
		"source_catalog_index": int(generated.get("source_catalog_index", -1)),
		"failures": failures,
		"validator_failures": validator.get("failures", []),
		"route_link_count": int(metrics.get("route_link_count", 0)),
		"route_link_without_blocker_count": int(metrics.get("route_link_without_blocker_count", -1)),
		"route_link_without_guard_count": int(metrics.get("route_link_without_guard_count", -1)),
		"connection_blocker_count": int(metrics.get("connection_blocker_count", 0)),
		"connection_guard_count": int(metrics.get("connection_guard_count", 0)),
		"town_count": int(metrics.get("town_count", 0)),
		"mine_count": int(metrics.get("mine_count", 0)),
		"reward_count": int(metrics.get("reward_count", 0)),
	}

func _check_metric(metrics: Dictionary, key: String, expected: int, failures: Array) -> void:
	if int(metrics.get(key, -999999)) != expected:
		failures.append("%s_expected_%d_got_%d" % [key, expected, int(metrics.get(key, -999999))])

func _check_template_coverage(player_count: int, expected: Array, seen: Dictionary, failures: Array) -> void:
	for template_id in expected:
		if not seen.has(String(template_id)):
			failures.append({
				"case_id": "template_coverage_%dp" % player_count,
				"ok": false,
				"missing_template_id": String(template_id),
				"seen": seen.keys(),
			})

func _fail(message: String, detail: Dictionary) -> void:
	push_error("%s: %s %s" % [REPORT_ID, message, JSON.stringify(detail)])
	get_tree().quit(1)
