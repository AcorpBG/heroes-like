extends Node

const ScenarioSelectRules = preload("res://scripts/core/ScenarioSelectRules.gd")

const DEFAULT_OUTPUT_DIR := ".artifacts/rmg_h3m_native_phase_drift_audit"
const DEFAULT_CASE_ID := "s_randomnumberofplayers"
const DEFAULT_OWNER_PATH := "res://maps/h3m-maps/S-RandomNumberofplayers.h3m"
const DEFAULT_SEED := "11"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_dir := _arg_value("--out", DEFAULT_OUTPUT_DIR)
	var case_id := _arg_value("--case-id", DEFAULT_CASE_ID)
	var owner_path := _arg_value("--owner", DEFAULT_OWNER_PATH)
	var seed := _arg_value("--seed", DEFAULT_SEED)
	var absolute_output_dir := ProjectSettings.globalize_path(output_dir)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_output_dir)
	if mkdir_error != OK:
		_finish({
			"schema_id": "rmg_h3m_native_phase_snapshot_v1",
			"status": "failed",
			"error": "output_dir_create_failed",
			"error_code": mkdir_error,
			"output_dir": output_dir,
		}, 1)
		return
	if not ClassDB.class_exists("MapPackageService"):
		_finish({
			"schema_id": "rmg_h3m_native_phase_snapshot_v1",
			"status": "failed",
			"error": "MapPackageService native class is not available.",
		}, 1)
		return

	var service: Variant = ClassDB.instantiate("MapPackageService")
	var config := ScenarioSelectRules.build_random_map_player_config(
		seed,
		"",
		"",
		3,
		"land",
		false,
		"homm3_small",
		ScenarioSelectRules.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
	)
	var inspection_started_msec := Time.get_ticks_msec()
	var inspection: Dictionary = service.inspect_h3maped_small_rmg_port(config)
	var inspection_wall_msec := Time.get_ticks_msec() - inspection_started_msec
	var generation_started_msec := Time.get_ticks_msec()
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "rmg_h3m_native_phase_drift_%s" % case_id})
	var generation_wall_msec := Time.get_ticks_msec() - generation_started_msec

	var native_path := absolute_output_dir.path_join("%s.amap" % case_id)
	var adoption_summary := {}
	if bool(generated.get("ok", false)):
		var adoption_started_msec := Time.get_ticks_msec()
		var adoption: Dictionary = service.convert_generated_payload(generated, {
			"feature_gate": "rmg_h3m_native_phase_drift_audit",
			"session_save_version": 9,
			"scenario_id": "rmg_h3m_native_phase_drift_%s" % case_id,
		})
		adoption_summary = _adoption_summary(adoption, Time.get_ticks_msec() - adoption_started_msec, service, native_path)
	else:
		adoption_summary = {
			"ok": false,
			"status": "generation_failed",
			"validation_status": String(generated.get("validation_status", "")),
			"validation_report": _summarize_value(generated.get("validation_report", {}), 3),
		}

	var report := {
		"schema_id": "rmg_h3m_native_phase_snapshot_v1",
		"status": "snapshotted" if bool(inspection.get("ok", false)) else "inspection_failed",
		"case_id": case_id,
		"owner_h3m_path": owner_path,
		"output_dir": output_dir,
		"absolute_output_dir": absolute_output_dir,
		"native_amap_path": native_path if bool(adoption_summary.get("save_ok", false)) else "",
		"config": config,
		"inspection_ok": bool(inspection.get("ok", false)),
		"generation_ok": bool(generated.get("ok", false)),
		"generation_status": String(generated.get("full_generation_status", "")),
		"validation_status": String(generated.get("validation_status", "")),
		"timing": {
			"inspection_wall_msec": inspection_wall_msec,
			"generation_wall_msec": generation_wall_msec,
		},
		"normalized_config": generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {},
		"selection_identity": _summarize_value(inspection.get("selection_identity", {}), 3),
		"phase_summaries": _phase_summaries(inspection),
		"package_adoption": adoption_summary,
	}
	var report_path := absolute_output_dir.path_join("phase_snapshot.json")
	report["phase_snapshot_path"] = report_path
	_write_json(report_path, report)
	_write_markdown(absolute_output_dir.path_join("phase_snapshot.md"), report)
	_finish(report, 0 if bool(inspection.get("ok", false)) else 1)

func _adoption_summary(adoption: Dictionary, adoption_wall_msec: int, service: Variant, native_path: String) -> Dictionary:
	var result := {
		"ok": bool(adoption.get("ok", false)),
		"adoption_wall_msec": adoption_wall_msec,
		"conversion_profile": _summarize_value(adoption.get("conversion_profile", {}), 2),
		"save_ok": false,
		"native_path": "",
	}
	if not bool(adoption.get("ok", false)):
		result["status"] = "conversion_failed"
		result["error"] = _summarize_value(adoption, 2)
		return result
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		result["status"] = "conversion_failed_missing_map_document"
		return result
	var save_started_msec := Time.get_ticks_msec()
	var save_result: Dictionary = service.save_map_package(map_document, native_path, {
		"path_policy": "artifact_rmg_h3m_native_phase_drift_audit",
		"return_package": false,
	})
	result["save_wall_msec"] = Time.get_ticks_msec() - save_started_msec
	result["save_ok"] = bool(save_result.get("ok", false))
	result["native_path"] = native_path
	result["save_status"] = String((save_result.get("report", {}) as Dictionary).get("status", "")) if save_result.get("report", {}) is Dictionary else ""
	result["package_hash"] = String(save_result.get("package_hash", ""))
	return result

func _phase_summaries(report: Dictionary) -> Dictionary:
	var result := {}
	for phase_key in [
		"player_slot_assignment",
		"runtime_zone_records",
		"link_seed_setup",
		"coordinate_replay",
		"zone_footprint_source_nodes",
		"zone_boundary_and_span_fill",
		"terrain_materialization",
		"town_castle_phase",
		"mines_rewards_and_object_vector",
		"roads_and_rivers",
		"connections_blockers_guards",
		"generated_cell_decoration_bit_state",
		"decorative_obstacle_filler",
		"public_package_adoption",
		"final_h3m_writeout",
		"fast_structural_validator",
	]:
		var phase: Variant = report.get(phase_key, {})
		if phase is Dictionary and not phase.is_empty():
			result[phase_key] = _summarize_value(phase, 4)
	return result

func _summarize_value(value: Variant, depth: int) -> Variant:
	if depth <= 0:
		return _type_name_for_value(value)
	match typeof(value):
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var result := {}
			for key in source.keys():
				var nested: Variant = source[key]
				var key_string := String(key)
				match typeof(nested):
					TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_NIL:
						result[key_string] = nested
					TYPE_ARRAY:
						result["%s_count" % key_string] = (nested as Array).size()
						result["%s_sample" % key_string] = _array_sample(nested as Array, depth - 1)
					TYPE_PACKED_INT32_ARRAY:
						result[key_string] = _packed_int_summary(nested as PackedInt32Array)
					_:
						if nested is Dictionary:
							result[key_string] = _summarize_value(nested, depth - 1)
						else:
							result[key_string] = _type_name_for_value(nested)
			return result
		TYPE_ARRAY:
			return {
				"count": (value as Array).size(),
				"sample": _array_sample(value as Array, depth - 1),
			}
		TYPE_PACKED_INT32_ARRAY:
			return _packed_int_summary(value as PackedInt32Array)
		_:
			return value

func _array_sample(array: Array, depth: int) -> Array:
	var result := []
	var sample_count: int = min(array.size(), 8)
	for index in range(sample_count):
		result.append(_summarize_value(array[index], depth))
	return result

func _packed_int_summary(values: PackedInt32Array) -> Dictionary:
	var nonzero_count := 0
	var max_value := 0
	for value in values:
		if int(value) != 0:
			nonzero_count += 1
			max_value = max(max_value, int(value))
	return {
		"count": values.size(),
		"nonzero_count": nonzero_count,
		"max_value": max_value,
	}

func _type_name_for_value(value: Variant) -> String:
	return type_string(typeof(value))

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()

func _write_markdown(path: String, report: Dictionary) -> void:
	var lines := []
	lines.append("# RMG H3M Native Phase Snapshot")
	lines.append("")
	lines.append("- Case: `%s`" % String(report.get("case_id", "")))
	lines.append("- Owner H3M: `%s`" % String(report.get("owner_h3m_path", "")))
	lines.append("- Native AMAP: `%s`" % String(report.get("native_amap_path", "")))
	lines.append("- Inspection: `%s`, generation: `%s`, validation: `%s`" % [
		str(report.get("inspection_ok", false)),
		str(report.get("generation_ok", false)),
		String(report.get("validation_status", "")),
	])
	lines.append("")
	lines.append("## Phase Counts")
	var phase_summaries: Dictionary = report.get("phase_summaries", {})
	for phase_key in phase_summaries.keys():
		var phase: Dictionary = phase_summaries[phase_key]
		lines.append("- `%s`: status `%s`" % [String(phase_key), String(phase.get("status", ""))])
	lines.append("")
	lines.append("Full compact phase data is in `phase_snapshot.json`.")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()

func _arg_value(name: String, fallback: String) -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		if String(args[index]) == name and index + 1 < args.size():
			return String(args[index + 1])
	return fallback

func _finish(manifest: Dictionary, exit_code: int) -> void:
	print("RMG_H3M_NATIVE_PHASE_SNAPSHOT %s" % JSON.stringify({
		"schema_id": String(manifest.get("schema_id", "")),
		"status": String(manifest.get("status", "")),
		"case_id": String(manifest.get("case_id", "")),
		"phase_snapshot_path": String(manifest.get("phase_snapshot_path", "")),
		"native_amap_path": String(manifest.get("native_amap_path", "")),
		"inspection_ok": bool(manifest.get("inspection_ok", false)),
		"generation_ok": bool(manifest.get("generation_ok", false)),
	}))
	get_tree().quit(exit_code)
