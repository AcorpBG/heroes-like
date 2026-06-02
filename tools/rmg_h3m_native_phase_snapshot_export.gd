extends Node

const DEFAULT_OUTPUT_DIR := ".artifacts/rmg_h3m_native_phase_drift_audit"
const DEFAULT_CASE_ID := "s_randomnumberofplayers"
const DEFAULT_OWNER_PATH := "res://maps/h3m-maps/S-RandomNumberofplayers.h3m"
const DEFAULT_SEED := "11"
const RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO := "native_catalog_auto"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_dir := _arg_value("--out", DEFAULT_OUTPUT_DIR)
	var case_id := _arg_value("--case-id", DEFAULT_CASE_ID)
	var owner_path := _arg_value("--owner", DEFAULT_OWNER_PATH)
	var seed := _arg_value("--seed", DEFAULT_SEED)
	var player_count := int(_arg_value("--players", "3"))
	var human_players := int(_arg_value("--human-players", "1"))
	var computer_players: int = max(0, player_count - human_players)
	var controlled_reference_manifest_path := _arg_value("--controlled-reference-manifest", "")
	var water_mode := _arg_value("--water", "land")
	var level_count := int(_arg_value("--level-count", "1"))
	var size_class_id := _arg_value("--size-class-id", "homm3_small")
	var controlled_reference_manifest := {}
	if controlled_reference_manifest_path != "":
		controlled_reference_manifest = _read_json_file(controlled_reference_manifest_path)
		var controlled_inputs: Dictionary = controlled_reference_manifest.get("inputs", {}) if controlled_reference_manifest.get("inputs", {}) is Dictionary else {}
		var controlled_identity: Dictionary = controlled_reference_manifest.get("controlled_identity", {}) if controlled_reference_manifest.get("controlled_identity", {}) is Dictionary else {}
		if not controlled_inputs.is_empty():
			seed = String(controlled_inputs.get("seed", seed))
			player_count = int(controlled_inputs.get("players", player_count))
			human_players = int(controlled_inputs.get("human_players", human_players))
			computer_players = int(controlled_inputs.get("computer_only_players", max(0, player_count - human_players)))
			water_mode = String(controlled_inputs.get("water", water_mode))
			level_count = int(controlled_inputs.get("level_count", level_count))
			size_class_id = _size_class_from_controlled_inputs(controlled_inputs, size_class_id)
		elif not controlled_identity.is_empty():
			seed = String(controlled_identity.get("requested_seed", controlled_identity.get("seed", seed)))
			player_count = int(controlled_identity.get("players", player_count))
			computer_players = max(0, player_count - human_players)
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
	var config := _build_native_random_map_config(seed, player_count, water_mode, level_count, size_class_id)
	config["player_constraints"]["human_count"] = human_players
	config["player_constraints"]["computer_count"] = computer_players
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
		"controlled_reference_manifest_path": controlled_reference_manifest_path,
		"controlled_reference_manifest_inputs": controlled_reference_manifest.get("inputs", {}) if controlled_reference_manifest.get("inputs", {}) is Dictionary else {},
		"controlled_reference_manifest_identity": controlled_reference_manifest.get("controlled_identity", {}) if controlled_reference_manifest.get("controlled_identity", {}) is Dictionary else {},
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
		"selection_diagnostics": _selection_diagnostics(inspection),
		"phase_summaries": _phase_summaries(inspection),
		"road_comparison_inputs": _road_comparison_inputs(inspection),
		"package_adoption": adoption_summary,
	}
	var report_path := absolute_output_dir.path_join("phase_snapshot.json")
	report["phase_snapshot_path"] = report_path
	_write_json(report_path, report)
	_write_markdown(absolute_output_dir.path_join("phase_snapshot.md"), report)
	_finish(report, 0 if bool(inspection.get("ok", false)) else 1)

func _selection_diagnostics(inspection: Dictionary) -> Dictionary:
	var selection: Dictionary = inspection.get("selection_identity", {}) if inspection.get("selection_identity", {}) is Dictionary else {}
	var accepted: Array = inspection.get("accepted_templates", []) if inspection.get("accepted_templates", []) is Array else []
	var ids := []
	var catalog_indices := []
	var names := []
	for value in accepted:
		if not value is Dictionary:
			continue
		var record: Dictionary = value
		ids.append(String(record.get("id", "")))
		catalog_indices.append(int(record.get("source_catalog_index", -1)))
		names.append(String(record.get("source_name", "")))
	return {
		"schema_id": "rmg_h3maped_template_selection_diagnostics_v1",
		"accepted_template_count": accepted.size(),
		"accepted_template_ids": ids,
		"accepted_source_catalog_indices": catalog_indices,
		"accepted_source_names": names,
		"rng_first_value": int(selection.get("rng_first_value", -1)),
		"template_preselection_rng_call_count": int(selection.get("template_preselection_rng_call_count", 0)),
		"template_selection_rng_value": int(selection.get("template_selection_rng_value", selection.get("rng_first_value", -1))),
		"selected_vector_index": int(selection.get("selected_vector_index", -1)),
		"source_template_id": String(selection.get("source_template_id", "")),
		"source_catalog_index": int(selection.get("source_catalog_index", -1)),
	}

func _build_native_random_map_config(seed: String, player_count: int, water_mode: String, level_count: int, size_class_id: String) -> Dictionary:
	var width := 36
	var height := 36
	match size_class_id:
		"homm3_medium":
			width = 72
			height = 72
		"homm3_large":
			width = 108
			height = 108
		"homm3_extra_large":
			width = 144
			height = 144
		_:
			width = 36
			height = 36
	var normalized_water := "normal_water" if water_mode == "normal_water" else ("islands" if water_mode == "islands" else "land")
	return {
		"generator_version": "native_rmg_h3maped_phase_snapshot_export",
		"seed": seed,
		"size": {
			"preset": "native_phase_snapshot_export",
			"size_class_id": size_class_id,
			"source_width": width,
			"source_height": height,
			"requested_width": width,
			"requested_height": height,
			"width": width,
			"height": height,
			"water_mode": normalized_water,
			"level_count": max(1, level_count),
		},
		"player_constraints": {
			"human_count": 1,
			"player_count": clampi(player_count, 2, 8),
			"computer_count": max(1, player_count - 1),
			"team_mode": "free_for_all",
		},
		"profile": {
			"id": "",
			"template_id": "",
			"guard_strength_profile": "normal",
			"faction_ids": [],
		},
		"template_selection": {
			"mode": RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO,
			"selection_deferred_to_native": true,
			"fallback_template_id": "",
			"fallback_profile_id": "",
		},
	}

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

func _road_comparison_inputs(report: Dictionary) -> Dictionary:
	var roads: Dictionary = report.get("roads_and_rivers", {}) if report.get("roads_and_rivers", {}) is Dictionary else {}
	var serialization: Dictionary = roads.get("road_overlay_serialization", {}) if roads.get("road_overlay_serialization", {}) is Dictionary else {}
	return {
		"schema_id": "rmg_native_private_road_comparison_inputs_v1",
		"status": String(roads.get("status", "")),
		"generator_coordinate_records": roads.get("generator_coordinate_records", []),
		"generator_coordinate_record_count": int(roads.get("generator_coordinate_record_count", 0)),
		"excluded_local_coordinate_records": roads.get("excluded_local_coordinate_records", []),
		"excluded_local_coordinate_record_count": int(roads.get("excluded_local_coordinate_record_count", 0)),
		"complete_executable_vector_claim": bool(roads.get("complete_executable_vector_claim", false)),
		"complete_executable_vector_blocker": String(roads.get("complete_executable_vector_blocker", "")),
		"route_pair_policy": String(roads.get("route_pair_policy", "")),
		"pair_candidate_records": roads.get("pair_candidate_records", []),
		"pair_candidate_iteration_count": int(roads.get("pair_candidate_iteration_count", 0)),
		"accepted_chain_records": roads.get("accepted_chain_records", []),
		"accepted_predecessor_chain_count": int(roads.get("accepted_predecessor_chain_count", 0)),
		"road_overlay_cell_records": roads.get("road_overlay_cell_records", []),
		"road_overlay_cell_count": int(roads.get("road_overlay_cell_count", 0)),
		"selected_road_type": int(roads.get("selected_road_type", 0)),
		"road_eligibility_bit_25_status": String(roads.get("road_eligibility_bit_25_status", "")),
		"tile_byte_4_road_type_u8": serialization.get("tile_byte_4_road_type_u8", PackedInt32Array()),
		"tile_byte_5_road_art_u8": serialization.get("tile_byte_5_road_art_u8", PackedInt32Array()),
		"tile_byte_6_road_flags_u8": serialization.get("tile_byte_6_road_flags_u8", PackedInt32Array()),
	}

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

func _read_json_file(path: String) -> Dictionary:
	var resolved_path := path
	if not path.begins_with("res://") and not path.begins_with("user://") and not path.is_absolute_path():
		resolved_path = ProjectSettings.globalize_path(path)
	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

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

func _size_class_from_controlled_inputs(inputs: Dictionary, fallback: String) -> String:
	var size_name := String(inputs.get("size", "")).strip_edges()
	if size_name != "":
		if size_name.begins_with("homm3_"):
			return size_name
		return "homm3_%s" % size_name
	var width := int(inputs.get("width", 0))
	var height := int(inputs.get("height", 0))
	if width == 36 and height == 36:
		return "homm3_small"
	if width == 72 and height == 72:
		return "homm3_medium"
	if width == 108 and height == 108:
		return "homm3_large"
	if width == 144 and height == 144:
		return "homm3_extra_large"
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
