extends Node

const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const STATUS_SETS := {
	"set_a": ["status_harried", "status_mire_harried", "status_rooted", "status_staggered"],
	"set_b_overflow": ["status_fogbound", "status_obituary_marked", "status_harried", "status_flare_revealed", "status_readiness_prepared"],
}
const EXPECTED_PATHS := {
	"status_harried": "res://art/battle/runtime/status_effects/status_harried_hooked_pennant.png",
	"status_mire_harried": "res://art/battle/runtime/status_effects/status_mire_harried_reedjaw_track.png",
	"status_staggered": "res://art/battle/runtime/status_effects/status_staggered_dented_helm.png",
	"status_rooted": "res://art/battle/runtime/status_effects/status_rooted_thornbound_boot.png",
	"status_fogbound": "res://art/battle/runtime/status_effects/status_fogbound_mist_lantern.png",
	"status_obituary_marked": "res://art/battle/runtime/status_effects/status_obituary_marked_mourning_bell.png",
	"status_overheated": "res://art/battle/runtime/status_effects/status_overheated_vent_plate.png",
	"status_rivet_exposed": "res://art/battle/runtime/status_effects/status_rivet_exposed_broken_seam.png",
	"status_flare_revealed": "res://art/battle/runtime/status_effects/status_flare_revealed_open_shutter.png",
	"status_readiness_prepared": "res://art/battle/runtime/status_effects/status_readiness_prepared_command_writ.png",
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
	for index in range(VIEWPORT_SIZES.size()):
		var viewport_size: Vector2i = VIEWPORT_SIZES[index]
		var set_id := "set_a" if index == 0 else "set_b_overflow"
		print("BATTLE_STATUS_EFFECT_BADGE_CASE_START %s %dx%d" % [set_id, viewport_size.x, viewport_size.y])
		var row := await _run_case(viewport_size, set_id, STATUS_SETS.get(set_id, []))
		if not bool(row.get("ok", false)):
			_finish_with_error("Battle status-effect badge case failed: %s" % JSON.stringify(row))
			return
		_rows.append(row)
	SettingsService.settings = _original_settings
	SettingsService.apply_settings()
	print("BATTLE_STATUS_EFFECT_BADGE_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"mapped_status_count": EXPECTED_PATHS.size(),
		"unique_runtime_texture_count": EXPECTED_PATHS.size(),
		"save_version": SessionStateStore.SAVE_VERSION,
		"rows": _rows,
	}))
	get_tree().quit(0)

func _run_case(viewport_size: Vector2i, set_id: String, status_ids_value: Variant) -> Dictionary:
	var status_ids: Array = status_ids_value if status_ids_value is Array else []
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	print("BATTLE_STATUS_EFFECT_BADGE_CHECKPOINT session_created %s" % set_id)
	var encounter := _first_encounter(session)
	if encounter.is_empty():
		return {"ok": false, "reason": "missing_encounter", "viewport": viewport_size, "set_id": set_id}
	session.battle = BattleRules.create_battle_payload(session, encounter)
	print("BATTLE_STATUS_EFFECT_BADGE_CHECKPOINT battle_created %s" % set_id)
	session = SessionState.set_active_session(session)
	var shell: Node = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("BATTLE_STATUS_EFFECT_BADGE_CHECKPOINT shell_ready %s" % set_id)
	var board = shell.get_node_or_null("%BattleBoard")
	if board == null:
		shell.queue_free()
		await get_tree().process_frame
		return {"ok": false, "reason": "missing_board", "viewport": viewport_size, "set_id": set_id}
	var authority_before: Dictionary = session.to_dict()
	var presentation_snapshot: Dictionary = session.battle.duplicate(true)
	var stacks: Array = presentation_snapshot.get("stacks", []) if presentation_snapshot.get("stacks", []) is Array else []
	if stacks.size() < 2:
		shell.queue_free()
		await get_tree().process_frame
		return {"ok": false, "reason": "insufficient_stacks", "viewport": viewport_size, "set_id": set_id}
	var current_round := int(presentation_snapshot.get("round", 1))
	stacks[0]["effects"] = []
	stacks[1]["effects"] = []
	if set_id.ends_with("_overflow"):
		for index in range(3):
			stacks[0]["effects"].append(_effect(String(status_ids[index]), current_round + index + 1))
		for index in range(3, status_ids.size()):
			stacks[1]["effects"].append(_effect(String(status_ids[index]), current_round + index + 1))
		stacks[1]["effects"].append(_effect("status_rooted", current_round - 1))
	else:
		stacks[0]["effects"] = [_effect(String(status_ids[0]), current_round + 1), _effect(String(status_ids[1]), current_round + 1)]
		stacks[1]["effects"] = [_effect(String(status_ids[2]), current_round + 2), _effect(String(status_ids[3]), current_round + 2)]
	presentation_snapshot["stacks"] = stacks
	board.call("set_battle_presentation_snapshot", presentation_snapshot)
	await get_tree().process_frame
	await get_tree().process_frame
	print("BATTLE_STATUS_EFFECT_BADGE_CHECKPOINT snapshot_ready %s" % set_id)
	var art_summary: Dictionary = board.call("validation_battle_status_effect_art_summary")
	var layout_summary: Dictionary = board.call("validation_hex_layout_summary")
	var missing_profile: Dictionary = board.call(
		"validation_battle_status_effect_art_profile",
		"status_harried",
		"res://art/battle/runtime/status_effects/missing_validation_asset.png"
	)
	var stack_rows: Array = layout_summary.get("stack_cells", []) if layout_summary.get("stack_cells", []) is Array else []
	var active_badge_rows := []
	for stack_row_value in stack_rows:
		if not (stack_row_value is Dictionary):
			continue
		var badge_summary: Dictionary = stack_row_value.get("status_effect_badges", {}) if stack_row_value.get("status_effect_badges", {}) is Dictionary else {}
		if int(badge_summary.get("active_status_count", 0)) > 0:
			active_badge_rows.append(badge_summary)
	var expected_overflow := 1 if set_id.ends_with("_overflow") else 0
	var overflow_exact := false
	var visible_total := 0
	var ordered_ids := []
	for badge_row in active_badge_rows:
		visible_total += int(badge_row.get("visible_badge_count", 0))
		ordered_ids.append_array(badge_row.get("ordered_status_ids", []))
		if int(badge_row.get("overflow_count", 0)) == expected_overflow:
			overflow_exact = true
	var expected_visible := 4
	var ordering_exact := true
	if set_id.ends_with("_overflow"):
		ordering_exact = ordered_ids == status_ids
	var summary_exact: bool = String(art_summary.get("schema_id", "")) == "battle_status_effect_art_manifest_v1" \
		and String(art_summary.get("presentation_model", "")) == "compact_imported_status_badges_with_non_color_polarity_foundation_and_procedural_mark_fallback" \
		and int(art_summary.get("mapped_status_count", 0)) == EXPECTED_PATHS.size() \
		and int(art_summary.get("loaded_texture_count", 0)) == EXPECTED_PATHS.size() \
		and int(art_summary.get("unique_silhouette_count", 0)) == EXPECTED_PATHS.size() \
		and art_summary.get("missing_texture_paths", []).is_empty() \
		and int(art_summary.get("max_visible_badges", 0)) == 2 \
		and int(art_summary.get("texture_cache_count", 0)) == EXPECTED_PATHS.size()
	var missing_fails_closed: bool = String(missing_profile.get("art_path", "")) == "res://art/battle/runtime/status_effects/missing_validation_asset.png" \
		and not bool(missing_profile.get("art_loaded", true)) \
		and bool(missing_profile.get("uses_procedural_mark_fallback", false))
	var badge_exact := visible_total == expected_visible and overflow_exact and ordering_exact
	print("BATTLE_STATUS_EFFECT_BADGE_CHECKPOINT validation_ready %s" % set_id)
	var capture_ok: bool = await _capture_if_requested(viewport_size, set_id)
	print("BATTLE_STATUS_EFFECT_BADGE_CHECKPOINT capture_ready %s" % set_id)
	var remaining_identities_exact := true
	if set_id.ends_with("_overflow"):
		var remaining_snapshot := presentation_snapshot.duplicate(true)
		var remaining_stacks: Array = remaining_snapshot.get("stacks", []) if remaining_snapshot.get("stacks", []) is Array else []
		remaining_stacks[0]["effects"] = [
			_effect("status_overheated", current_round + 1),
			_effect("status_rivet_exposed", current_round + 1),
		]
		remaining_stacks[1]["effects"] = []
		remaining_snapshot["stacks"] = remaining_stacks
		board.call("set_battle_presentation_snapshot", remaining_snapshot)
		await get_tree().process_frame
		await get_tree().process_frame
		var remaining_badges: Dictionary = board.call("validation_stack_status_effect_badges", remaining_stacks[0])
		remaining_identities_exact = remaining_badges.get("visible_status_ids", []) == ["status_overheated", "status_rivet_exposed"] \
			and await _capture_if_requested(viewport_size, "set_c_remaining")
	var authority_exact: bool = session.to_dict() == authority_before
	var row := {
		"ok": summary_exact and missing_fails_closed and badge_exact and capture_ok and remaining_identities_exact and authority_exact and SessionStateStore.SAVE_VERSION == 9,
		"viewport": {"width": viewport_size.x, "height": viewport_size.y},
		"set_id": set_id,
		"status_ids": status_ids,
		"visible_badge_count": visible_total,
		"overflow_count": expected_overflow,
		"expired_effect_filtered": not set_id.ends_with("_overflow") or active_badge_rows.size() == 2,
		"deterministic_order_exact": ordering_exact,
		"remaining_identities_exact": remaining_identities_exact,
		"missing_asset_fails_closed": missing_fails_closed,
		"session_authority_exact": authority_exact,
		"texture_cache_count": int(art_summary.get("texture_cache_count", 0)),
	}
	shell.queue_free()
	await get_tree().process_frame
	return row

func _effect(status_id: String, expires_after_round: int) -> Dictionary:
	return {
		"effect_id": status_id,
		"label": status_id.trim_prefix("status_").replace("_", " ").capitalize(),
		"kind": "status",
		"modifiers": {},
		"expires_after_round": expires_after_round,
		"source": "presentation_validation",
	}

func _capture_if_requested(viewport_size: Vector2i, set_id: String) -> bool:
	if OS.get_environment("BATTLE_STATUS_EFFECT_CAPTURE") != "1":
		return true
	await get_tree().process_frame
	var output_dir := "res://.artifacts/battle_status_effect_badges"
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
