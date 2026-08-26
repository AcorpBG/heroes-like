extends Node

const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]

var _rows := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	SettingsService.settings = SettingsService.build_default_settings()
	SettingsService.apply_settings()
	for viewport_size in VIEWPORT_SIZES:
		var row := await _run_viewport(viewport_size)
		if not bool(row.get("ok", false)):
			push_error("Battle movement perimeter failed at %s: %s" % [viewport_size, JSON.stringify(row)])
			get_tree().quit(1)
			return
		_rows.append(row)
	print("BATTLE_MOVEMENT_RANGE_PERIMETER_RUNTIME_REPORT %s" % JSON.stringify({"ok": true, "rows": _rows}))
	get_tree().quit(0)

func _run_viewport(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		return {"ok": false, "reason": "missing_encounter", "viewport": viewport_size}
	session.battle = BattleRules.create_battle_payload(session, encounter)
	session = SessionState.set_active_session(session)
	var shell: Node = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var authority_before: Dictionary = session.to_dict()
	var board = shell.get_node_or_null("%BattleBoard")
	if board == null or not board.has_method("validation_hex_layout_summary"):
		shell.queue_free()
		await get_tree().process_frame
		return {"ok": false, "reason": "missing_board_summary", "viewport": viewport_size}
	var summary: Dictionary = board.call("validation_hex_layout_summary")
	var independent := _independent_region_summary(summary.get("legal_destinations", []))
	var legal_count := int(summary.get("legal_destination_count", -1))
	var boundary_count := int(summary.get("movement_range_boundary_segment_count", -1))
	var internal_count := int(summary.get("movement_range_internal_shared_edge_count", -1))
	var exact := legal_count > 0 \
		and int(summary.get("movement_range_cell_count", -2)) == legal_count \
		and String(summary.get("movement_range_visual_model", "")) == "broken_exposed_edge_perimeter_center_pips_near_transparent_fill" \
		and boundary_count == int(independent.get("boundary_segment_count", -2)) \
		and internal_count == int(independent.get("internal_shared_edge_count", -2)) \
		and boundary_count > 0 \
		and internal_count > 0 \
		and boundary_count < legal_count * 3 \
		and boundary_count + internal_count * 2 == legal_count * 6 \
		and bool(summary.get("movement_range_region_edge_balance_exact", false)) \
		and bool(independent.get("edge_balance_exact", false)) \
		and not bool(independent.get("duplicate_cell", true)) \
		and not bool(summary.get("movement_range_internal_edges_drawn", true)) \
		and int(summary.get("movement_range_destination_pip_count", -2)) == legal_count \
		and not bool(summary.get("movement_range_complete_cell_outlines", true)) \
		and bool(summary.get("movement_range_all_legal_cells_drawn", false)) \
		and not bool(summary.get("movement_range_hover_only", true)) \
		and bool(summary.get("movement_range_below_active_targets_and_stacks", false)) \
		and String(summary.get("movement_range_action_authority", "")) == "legal_destinations_for_active_stack" \
		and is_equal_approx(float(summary.get("movement_range_fill_radius_factor", 0.0)), 0.58) \
		and is_equal_approx(float(summary.get("movement_range_fill_alpha", 0.0)), 0.012) \
		and is_equal_approx(float(summary.get("movement_range_contour_radius_factor", 0.0)), 0.90) \
		and is_equal_approx(float(summary.get("movement_range_contour_segment_factor", 0.0)), 0.72) \
		and is_equal_approx(float(summary.get("movement_range_contour_alpha", 0.0)), 0.48) \
		and is_equal_approx(float(summary.get("movement_range_contour_width", 0.0)), 1.6) \
		and is_equal_approx(float(summary.get("movement_range_pip_radius_factor", 0.0)), 0.040) \
		and is_equal_approx(float(summary.get("movement_range_pip_alpha", 0.0)), 0.46) \
		and session.to_dict() == authority_before
	var row := {
		"ok": exact,
		"viewport": {"width": viewport_size.x, "height": viewport_size.y},
		"legal_destination_count": legal_count,
		"boundary_segment_count": boundary_count,
		"internal_shared_edge_count": internal_count,
		"old_repeated_tick_count": legal_count * 3,
		"destination_pip_count": int(summary.get("movement_range_destination_pip_count", -1)),
		"edge_balance_exact": bool(summary.get("movement_range_region_edge_balance_exact", false)),
		"session_authority_exact": session.to_dict() == authority_before,
	}
	shell.queue_free()
	await get_tree().process_frame
	return row

func _first_encounter(session) -> Dictionary:
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary:
			return encounter_value.duplicate(true)
	return {}

func _independent_region_summary(destinations_value: Variant) -> Dictionary:
	var destinations: Array = destinations_value if destinations_value is Array else []
	var cells: Array[Vector2i] = []
	var cell_keys := {}
	var duplicate_cell := false
	for destination in destinations:
		if not (destination is Dictionary):
			continue
		var cell := Vector2i(int(destination.get("q", -1)), int(destination.get("r", -1)))
		var key := "%d,%d" % [cell.x, cell.y]
		if cell_keys.has(key):
			duplicate_cell = true
			continue
		cell_keys[key] = true
		cells.append(cell)
	var boundary_segment_count := 0
	var internal_directed_edge_count := 0
	for cell in cells:
		var offsets := [
			Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0),
			Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 0),
		] if cell.y % 2 == 0 else [
			Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0),
		]
		for offset_value in offsets:
			var neighbor: Vector2i = cell + offset_value
			if cell_keys.has("%d,%d" % [neighbor.x, neighbor.y]):
				internal_directed_edge_count += 1
			else:
				boundary_segment_count += 1
	var internal_shared_edge_count := int(internal_directed_edge_count / 2)
	return {
		"duplicate_cell": duplicate_cell,
		"boundary_segment_count": boundary_segment_count,
		"internal_shared_edge_count": internal_shared_edge_count,
		"edge_balance_exact": boundary_segment_count + internal_shared_edge_count * 2 == cells.size() * 6,
	}
