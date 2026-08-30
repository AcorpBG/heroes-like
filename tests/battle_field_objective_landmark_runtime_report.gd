extends Node

const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const OBJECTIVE_SETS := {
	"set_a": ["cover_line", "obstruction_line", "lane_battery", "hazard_zone"],
	"set_b": ["breach_point", "ritual_pylon", "signal_beacon", "supply_post"],
}
const EXPECTED_PATHS := {
	"cover_line": "res://art/battle/runtime/field_objectives/cover_line_briar_bulwark.png",
	"obstruction_line": "res://art/battle/runtime/field_objectives/obstruction_line_crossed_stakes.png",
	"lane_battery": "res://art/battle/runtime/field_objectives/lane_battery_splitrail.png",
	"hazard_zone": "res://art/battle/runtime/field_objectives/hazard_zone_mireglass_basin.png",
	"breach_point": "res://art/battle/runtime/field_objectives/breach_point_broken_gate.png",
	"ritual_pylon": "res://art/battle/runtime/field_objectives/ritual_pylon_resonance_stone.png",
	"signal_beacon": "res://art/battle/runtime/field_objectives/signal_beacon_tripod_lantern.png",
	"supply_post": "res://art/battle/runtime/field_objectives/supply_post_frontier_stores.png",
}
const EXPECTED_CONTROL_SHAPES := {
	"player": "diamond",
	"enemy": "downward_triangle",
	"neutral": "hollow_square",
}
const EXPECTED_AUTHORED_TYPE_COUNTS := {
	"cover_line": 22,
	"obstruction_line": 9,
	"lane_battery": 13,
	"hazard_zone": 14,
	"breach_point": 7,
	"ritual_pylon": 8,
	"signal_beacon": 17,
	"supply_post": 18,
}

var _rows := []
var _original_settings := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_original_settings = SettingsService.settings.duplicate(true)
	SettingsService.settings = SettingsService.build_default_settings()
	SettingsService.settings["ui_scale_percent"] = 100
	SettingsService.settings["high_contrast"] = false
	SettingsService.settings["reduced_motion"] = false
	SettingsService.apply_settings()
	var coverage := _authored_coverage_summary()
	if not bool(coverage.get("ok", false)):
		_finish_with_error("Authored objective coverage failed: %s" % JSON.stringify(coverage))
		return
	for viewport_size in VIEWPORT_SIZES:
		for set_id in OBJECTIVE_SETS:
			var row := await _run_case(viewport_size, String(set_id), OBJECTIVE_SETS.get(set_id, []))
			if not bool(row.get("ok", false)):
				_finish_with_error("Field-objective landmark case failed: %s" % JSON.stringify(row))
				return
			_rows.append(row)
	SettingsService.settings = _original_settings
	SettingsService.apply_settings()
	print("BATTLE_FIELD_OBJECTIVE_LANDMARK_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"authored_objective_count": int(coverage.get("authored_objective_count", 0)),
		"authored_encounter_count": int(coverage.get("authored_encounter_count", 0)),
		"mapped_objective_type_count": EXPECTED_PATHS.size(),
		"unique_runtime_texture_count": EXPECTED_PATHS.size(),
		"control_shapes": EXPECTED_CONTROL_SHAPES,
		"save_version": SessionStateStore.SAVE_VERSION,
		"rows": _rows,
	}))
	get_tree().quit(0)

func _run_case(viewport_size: Vector2i, set_id: String, objective_types_value: Variant) -> Dictionary:
	var objective_types: Array = objective_types_value if objective_types_value is Array else []
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		return {"ok": false, "reason": "missing_encounter", "viewport": viewport_size, "set_id": set_id}
	session.battle = BattleRules.create_battle_payload(session, encounter)
	session = SessionState.set_active_session(session)
	var shell: Node = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var board = shell.get_node_or_null("%BattleBoard")
	if board == null:
		shell.queue_free()
		await get_tree().process_frame
		return {"ok": false, "reason": "missing_board", "viewport": viewport_size, "set_id": set_id}
	var authority_before: Dictionary = session.to_dict()
	var presentation_snapshot: Dictionary = session.battle.duplicate(true)
	presentation_snapshot[BattleRules.FIELD_OBJECTIVES_KEY] = _objective_records(objective_types)
	board.call("set_battle_presentation_snapshot", presentation_snapshot)
	await get_tree().process_frame
	await get_tree().process_frame
	var art_summary: Dictionary = board.call("validation_field_objective_art_summary")
	var layout_summary: Dictionary = board.call("validation_hex_layout_summary")
	var missing_profile: Dictionary = board.call(
		"validation_field_objective_art_profile",
		"cover_line",
		"res://art/battle/runtime/field_objectives/missing_validation_asset.png"
	)
	var marker_rows: Array = layout_summary.get("field_objective_cells", []) if layout_summary.get("field_objective_cells", []) is Array else []
	var board_rect: Rect2 = layout_summary.get("board_rect", Rect2()) if layout_summary.get("board_rect", Rect2()) is Rect2 else Rect2()
	var expected_controls := ["player", "enemy", "neutral", "player"]
	var markers_exact: bool = marker_rows.size() == objective_types.size()
	for index in range(marker_rows.size()):
		if not (marker_rows[index] is Dictionary):
			markers_exact = false
			continue
		var marker: Dictionary = marker_rows[index]
		var objective_type := String(objective_types[index]) if index < objective_types.size() else ""
		var control_side: String = String(expected_controls[index]) if index < expected_controls.size() else "neutral"
		var marker_rect: Rect2 = marker.get("marker_rect", Rect2()) if marker.get("marker_rect", Rect2()) is Rect2 else Rect2()
		markers_exact = markers_exact \
			and String(marker.get("type", "")) == objective_type \
			and String(marker.get("art_path", "")) == String(EXPECTED_PATHS.get(objective_type, "")) \
			and String(marker.get("alt_text", "")).strip_edges() != "" \
			and bool(marker.get("art_loaded", false)) \
			and not bool(marker.get("uses_legacy_geometry_fallback", true)) \
			and String(marker.get("control_side", "")) == control_side \
			and String(marker.get("control_shape", "")) == String(EXPECTED_CONTROL_SHAPES.get(control_side, "")) \
			and marker_rect.size.x >= 38.0 \
			and marker_rect.size.x <= 56.0 \
			and marker_rect.size == marker_rect.size.abs() \
			and board_rect.encloses(marker_rect)
	var summary_exact: bool = String(art_summary.get("schema_id", "")) == "battle_field_objective_art_manifest_v1" \
		and String(art_summary.get("presentation_model", "")) == "type_distinct_imported_landmark_with_non_color_control_shape_and_legacy_geometry_fallback" \
		and int(art_summary.get("mapped_objective_type_count", 0)) == EXPECTED_PATHS.size() \
		and int(art_summary.get("loaded_texture_count", 0)) == EXPECTED_PATHS.size() \
		and int(art_summary.get("unique_silhouette_count", 0)) == EXPECTED_PATHS.size() \
		and art_summary.get("missing_texture_paths", []).is_empty() \
		and Dictionary(art_summary.get("control_shapes", {})) == EXPECTED_CONTROL_SHAPES \
		and int(art_summary.get("texture_cache_count", 0)) == EXPECTED_PATHS.size()
	var missing_fails_closed: bool = String(missing_profile.get("art_path", "")) == "res://art/battle/runtime/field_objectives/missing_validation_asset.png" \
		and not bool(missing_profile.get("art_loaded", true)) \
		and bool(missing_profile.get("uses_legacy_geometry_fallback", false))
	var capture_ok: bool = await _capture_if_requested(viewport_size, set_id)
	var authority_exact: bool = session.to_dict() == authority_before
	var row := {
		"ok": summary_exact and markers_exact and missing_fails_closed and capture_ok and authority_exact and SessionStateStore.SAVE_VERSION == 9,
		"viewport": {"width": viewport_size.x, "height": viewport_size.y},
		"set_id": set_id,
		"objective_types": objective_types,
		"marker_count": marker_rows.size(),
		"all_imported_landmarks_loaded": markers_exact,
		"missing_asset_fails_closed": missing_fails_closed,
		"session_authority_exact": authority_exact,
		"texture_cache_count": int(art_summary.get("texture_cache_count", 0)),
	}
	shell.queue_free()
	await get_tree().process_frame
	return row

func _objective_records(objective_types: Array) -> Array:
	var controls := ["player", "enemy", "neutral", "player"]
	var result := []
	for index in range(objective_types.size()):
		var objective_type := String(objective_types[index])
		result.append({
			"id": "validation_%s" % objective_type,
			"type": objective_type,
			"label": objective_type.replace("_", " ").capitalize(),
			"summary": "Validation-only field objective.",
			"control_side": controls[index] if index < controls.size() else "neutral",
			"progress_side": "player" if index == 0 else "",
			"progress_value": 1 if index == 0 else 0,
			"capture_threshold": 2,
		})
	return result

func _authored_coverage_summary() -> Dictionary:
	var raw: Dictionary = ContentService.load_json("res://content/encounters.json")
	var encounters: Array = raw.get("items", []) if raw.get("items", []) is Array else []
	var type_counts := {}
	var authored_objective_count := 0
	for encounter_value in encounters:
		if not (encounter_value is Dictionary):
			continue
		for objective_value in encounter_value.get("field_objectives", []):
			if not (objective_value is Dictionary):
				continue
			var objective_type := String(objective_value.get("type", ""))
			type_counts[objective_type] = int(type_counts.get(objective_type, 0)) + 1
			authored_objective_count += 1
	return {
		"ok": encounters.size() == 113 \
			and authored_objective_count == 108 \
			and type_counts == EXPECTED_AUTHORED_TYPE_COUNTS \
			and type_counts.keys().all(func(objective_type): return EXPECTED_PATHS.has(objective_type)),
		"authored_encounter_count": encounters.size(),
		"authored_objective_count": authored_objective_count,
		"type_counts": type_counts,
	}

func _capture_if_requested(viewport_size: Vector2i, set_id: String) -> bool:
	if OS.get_environment("BATTLE_FIELD_OBJECTIVE_CAPTURE") != "1":
		return true
	await RenderingServer.frame_post_draw
	var output_dir := "res://.artifacts/battle_field_objective_landmarks"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return false
	return image.save_png("%s/%s_%dx%d.png" % [output_dir, set_id, viewport_size.x, viewport_size.y]) == OK

func _first_encounter(session) -> Dictionary:
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary:
			return encounter_value.duplicate(true)
	return {}

func _finish_with_error(message: String) -> void:
	SettingsService.settings = _original_settings
	SettingsService.apply_settings()
	push_error(message)
	get_tree().quit(1)
