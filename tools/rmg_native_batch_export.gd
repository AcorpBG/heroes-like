extends Node

const ScenarioSelectRules = preload("res://scripts/core/ScenarioSelectRules.gd")

const OWNER_H3M_DIR := "res://maps/h3m-maps"
const DEFAULT_OUTPUT_DIR := ".artifacts/rmg_native_batch_export"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_dir := _output_dir_from_args()
	var limit := _limit_from_args()
	var absolute_output_dir := ProjectSettings.globalize_path(output_dir)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_output_dir)
	if mkdir_error != OK:
		_finish({
			"schema_id": "rmg_native_batch_export_v1",
			"status": "failed",
			"error": "output_dir_create_failed",
			"output_dir": output_dir,
			"error_code": mkdir_error,
		}, 1)
		return
	if not ClassDB.class_exists("MapPackageService"):
		_finish({
			"schema_id": "rmg_native_batch_export_v1",
			"status": "failed",
			"error": "MapPackageService native class is not available.",
		}, 1)
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var cases := _owner_cases()
	if limit > 0 and cases.size() > limit:
		cases = cases.slice(0, limit)
	var manifest := {
		"schema_id": "rmg_native_batch_export_v1",
		"status": "exported",
		"owner_h3m_dir": OWNER_H3M_DIR,
		"output_dir": output_dir,
		"absolute_output_dir": absolute_output_dir,
		"case_limit": limit,
		"case_count": cases.size(),
		"exported_count": 0,
		"failed_count": 0,
		"cases": [],
	}
	for case in cases:
		var record := _export_case(service, case, output_dir, absolute_output_dir)
		manifest["cases"].append(record)
		if String(record.get("status", "")) == "exported":
			manifest["exported_count"] = int(manifest.get("exported_count", 0)) + 1
		else:
			manifest["failed_count"] = int(manifest.get("failed_count", 0)) + 1
	if int(manifest.get("failed_count", 0)) > 0:
		manifest["status"] = "partial"
	var manifest_path := absolute_output_dir.path_join("manifest.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		manifest["status"] = "partial"
		manifest["manifest_write_error"] = "failed_to_open_manifest"
		manifest["manifest_path"] = manifest_path
	else:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
		manifest["manifest_path"] = manifest_path
	_finish(manifest, 0 if int(manifest.get("failed_count", 0)) == 0 else 1)

func _output_dir_from_args() -> String:
	return _arg_value("--out", DEFAULT_OUTPUT_DIR)

func _limit_from_args() -> int:
	return int(_arg_value("--limit", "0"))

func _arg_value(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		if String(args[index]) == name and index + 1 < args.size():
			return String(args[index + 1])
	return fallback

func _owner_cases() -> Array:
	var result := []
	var dir := DirAccess.open(OWNER_H3M_DIR)
	if dir == null:
		return result
	for file_name in dir.get_files():
		if not file_name.to_lower().ends_with(".h3m"):
			continue
		var owner_path := OWNER_H3M_DIR.path_join(file_name)
		var case_id := _case_id_from_file_name(file_name)
		result.append({
			"id": case_id,
			"owner_path": owner_path,
			"file_name": file_name,
			"config": _config_for_owner_file(file_name, case_id),
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("id", "")) < String(right.get("id", "")))
	return result

func _config_for_owner_file(file_name: String, case_id: String) -> Dictionary:
	var lower_name := file_name.to_lower()
	var size_class_id := "homm3_medium"
	if lower_name.begins_with("s-"):
		size_class_id = "homm3_small"
	elif lower_name.begins_with("l-"):
		size_class_id = "homm3_large"
	elif lower_name.begins_with("xl-"):
		size_class_id = "homm3_extra_large"
	var water_mode := "land"
	if lower_name.contains("island"):
		water_mode = "islands"
	elif (lower_name.contains("normalw") or lower_name.contains("normalwater") or lower_name.contains("water")) and not lower_name.contains("nowater") and not lower_name.contains("no-water"):
		water_mode = "normal_water"
	var two_level := lower_name.contains("2level")
	var player_count := _player_count_for_file(lower_name, size_class_id)
	return ScenarioSelectRules.build_random_map_player_config(
		"native-batch-%s" % case_id,
		"",
		"",
		player_count,
		water_mode,
		two_level,
		size_class_id,
		ScenarioSelectRules.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
	)

func _player_count_for_file(lower_name: String, size_class_id: String) -> int:
	if lower_name.contains("2players"):
		return 2
	if lower_name.contains("4players"):
		return 4
	if size_class_id == "homm3_small":
		return 3
	if size_class_id == "homm3_medium":
		return 4
	return 5

func _export_case(service: Variant, case: Dictionary, output_dir: String, absolute_output_dir: String) -> Dictionary:
	var config: Dictionary = case.get("config", {})
	var case_id := String(case.get("id", "case"))
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "rmg_native_batch_export_%s" % case_id})
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var record := {
		"id": case_id,
		"owner_path": String(case.get("owner_path", "")),
		"config": config,
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"size_class_id": String(normalized.get("size_class_id", "")),
		"water_mode": String(normalized.get("water_mode", "")),
		"level_count": int(normalized.get("level_count", 0)),
		"generation_ok": bool(generated.get("ok", false)),
		"generation_status": String(generated.get("full_generation_status", "")),
		"validation_status": String(generated.get("validation_status", "")),
	}
	if not bool(generated.get("ok", false)):
		record["status"] = "generation_failed"
		record["error"] = generated.get("validation_report", generated)
		return record
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "rmg_native_batch_export",
		"session_save_version": 9,
		"scenario_id": "rmg_native_batch_export_%s" % case_id,
	})
	if not bool(adoption.get("ok", false)):
		record["status"] = "conversion_failed"
		record["error"] = adoption
		record["generated_validation_report"] = generated.get("validation_report", {})
		record["generated_validation_failures"] = (generated.get("validation_report", {}) as Dictionary).get("failures", []) if generated.get("validation_report", {}) is Dictionary else []
		return record
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		record["status"] = "conversion_failed"
		record["error"] = "missing_map_document"
		return record
	var native_path := absolute_output_dir.path_join("%s.amap" % case_id)
	var save_result: Dictionary = service.save_map_package(map_document, native_path, {"path_policy": "artifact_rmg_native_batch_export"})
	record["native_path"] = native_path
	record["native_project_relative_path"] = output_dir.path_join("%s.amap" % case_id)
	record["save"] = {
		"ok": bool(save_result.get("ok", false)),
		"status": String((save_result.get("report", {}) as Dictionary).get("status", "")) if save_result.get("report", {}) is Dictionary else "",
		"package_hash": String(save_result.get("package_hash", "")),
		"path": String(save_result.get("path", native_path)),
	}
	record["status"] = "exported" if bool(save_result.get("ok", false)) else "save_failed"
	return record

func _case_id_from_file_name(file_name: String) -> String:
	var id := file_name.get_basename().to_lower()
	for character in [" ", "-", ".", "(", ")", "[", "]"]:
		id = id.replace(character, "_")
	while id.contains("__"):
		id = id.replace("__", "_")
	return id.strip_edges()

func _finish(manifest: Dictionary, exit_code: int) -> void:
	print("RMG_NATIVE_BATCH_EXPORT %s" % JSON.stringify(manifest))
	get_tree().quit(exit_code)
