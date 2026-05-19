extends Node

const DEFAULT_OUTPUT_DIR := ".artifacts/rmg_h3maped_small_divergence_audit"
const REPORT_SCHEMA_ID := "rmg_h3maped_small_native_broad_snapshot_v1"

const CASES := [
	{"case_id": "exact_failed_seed_1270881600", "seed": "1270881600", "players": 2},
	{"case_id": "matrix_2p_seed_28", "seed": "28", "players": 2},
	{"case_id": "matrix_2p_seed_92", "seed": "92", "players": 2},
	{"case_id": "matrix_2p_seed_1", "seed": "1", "players": 2},
	{"case_id": "matrix_2p_seed_9", "seed": "9", "players": 2},
	{"case_id": "matrix_2p_seed_73", "seed": "73", "players": 2},
	{"case_id": "matrix_2p_seed_137", "seed": "137", "players": 2},
	{"case_id": "matrix_2p_seed_2", "seed": "2", "players": 2},
	{"case_id": "matrix_2p_seed_58", "seed": "58", "players": 2},
	{"case_id": "matrix_2p_seed_122", "seed": "122", "players": 2},
	{"case_id": "matrix_2p_seed_3", "seed": "3", "players": 2},
	{"case_id": "matrix_2p_seed_43", "seed": "43", "players": 2},
	{"case_id": "matrix_2p_seed_107", "seed": "107", "players": 2},
	{"case_id": "matrix_2p_seed_4", "seed": "4", "players": 2},
	{"case_id": "matrix_3p_seed_3", "seed": "3", "players": 3},
	{"case_id": "matrix_3p_seed_7", "seed": "7", "players": 3},
	{"case_id": "matrix_3p_seed_11", "seed": "11", "players": 3},
	{"case_id": "matrix_3p_seed_4", "seed": "4", "players": 3},
	{"case_id": "matrix_3p_seed_8", "seed": "8", "players": 3},
	{"case_id": "matrix_3p_seed_1", "seed": "1", "players": 3},
	{"case_id": "matrix_3p_seed_5", "seed": "5", "players": 3},
	{"case_id": "matrix_3p_seed_20", "seed": "20", "players": 3},
	{"case_id": "matrix_3p_seed_9", "seed": "9", "players": 3},
	{"case_id": "matrix_3p_seed_2", "seed": "2", "players": 3},
	{"case_id": "matrix_3p_seed_6", "seed": "6", "players": 3},
	{"case_id": "matrix_3p_seed_10", "seed": "10", "players": 3},
	{"case_id": "matrix_4p_seed_12", "seed": "12", "players": 4},
	{"case_id": "matrix_4p_seed_2", "seed": "2", "players": 4},
	{"case_id": "matrix_4p_seed_9", "seed": "9", "players": 4},
	{"case_id": "matrix_4p_seed_6", "seed": "6", "players": 4},
	{"case_id": "matrix_4p_seed_3", "seed": "3", "players": 4},
	{"case_id": "matrix_4p_seed_10", "seed": "10", "players": 4},
	{"case_id": "matrix_4p_seed_7", "seed": "7", "players": 4},
	{"case_id": "matrix_4p_seed_4", "seed": "4", "players": 4},
	{"case_id": "matrix_4p_seed_1", "seed": "1", "players": 4},
	{"case_id": "matrix_4p_seed_8", "seed": "8", "players": 4},
	{"case_id": "matrix_4p_seed_5", "seed": "5", "players": 4},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_dir := _arg_value("--out", DEFAULT_OUTPUT_DIR)
	var absolute_output_dir := ProjectSettings.globalize_path(output_dir)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_output_dir)
	if mkdir_error != OK:
		_finish({"schema_id": REPORT_SCHEMA_ID, "ok": false, "error": "output_dir_create_failed", "error_code": mkdir_error}, 1)
		return
	if not ClassDB.class_exists("MapPackageService"):
		_finish({"schema_id": REPORT_SCHEMA_ID, "ok": false, "error": "MapPackageService native class is not available."}, 1)
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var cases := []
	for case in CASES:
		cases.append(_run_case(service, case))
	var report := {
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"scope": "native Small 36x36 one-level land matrix; h3maped comparison handled by Python controlled-reference orchestrator",
		"case_count": cases.size(),
		"cases": cases,
	}
	var report_path := absolute_output_dir.path_join("native_broad_snapshot.json")
	_write_json(report_path, report)
	report["native_broad_snapshot_path"] = report_path
	_finish(report, 0)

func _run_case(service: Variant, case: Dictionary) -> Dictionary:
	var seed := String(case.get("seed", "1"))
	var player_count := int(case.get("players", 3))
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
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "h3maped_small_divergence_audit"})
	var validator: Dictionary = generated.get("fast_structural_validator", {}) if generated.get("fast_structural_validator", {}) is Dictionary else {}
	var metrics: Dictionary = validator.get("metrics", {}) if validator.get("metrics", {}) is Dictionary else {}
	var normalized: Dictionary = identity.get("normalized_config", {}) if identity.get("normalized_config", {}) is Dictionary else {}
	return {
		"case_id": String(case.get("case_id", "")),
		"seed": seed,
		"players": player_count,
		"ok": bool(generated.get("ok", false)) and String(validator.get("status", "")) == "strict_fast_structural_validator_pass_public_generation_ready",
		"generation_status": String(generated.get("generation_status", generated.get("status", ""))),
		"full_generation_status": String(generated.get("full_generation_status", "")),
		"validator_status": String(validator.get("status", "")),
		"validator_failure_count": int(validator.get("failure_count", -1)),
		"source_template_id": String(generated.get("source_template_id", normalized.get("template_id", ""))),
		"source_catalog_index": int(generated.get("source_catalog_index", -1)),
		"source_template_authority": String(generated.get("source_template_authority", "h3maped_exe_rng")),
		"metrics": metrics,
	}

func _arg_value(name: String, default_value: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		if args[index] == name and index + 1 < args.size():
			return String(args[index + 1])
	return default_value

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t", false) + "\n")

func _finish(report: Dictionary, exit_code: int) -> void:
	print("RMG_H3MAPED_SMALL_DIVERGENCE_NATIVE_EXPORT %s" % JSON.stringify(report))
	get_tree().quit(exit_code)
