extends Node

const REPORT_ID := "OVERWORLD_ACTION_FEEDBACK_VFX_ASSET_RUNTIME_REPORT"
const MANIFEST_PATH := "res://content/overworld_vfx_manifest.json"
const SOURCE_PATH := "res://art/overworld/source/action_feedback_vfx_source.png"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const EXPECTED_ASSETS := {
	"artifact_acquired": {
		"cue_id": "vfx_placeholder_artifact_claim",
		"texture_path": "res://art/overworld/runtime/vfx/artifact_claim.png",
	},
	"artifact_equipped": {
		"cue_id": "vfx_placeholder_slot_equip",
		"texture_path": "res://art/overworld/runtime/vfx/artifact_slot_equip.png",
	},
	"artifact_unequipped": {
		"cue_id": "vfx_placeholder_slot_unequip",
		"texture_path": "res://art/overworld/runtime/vfx/artifact_slot_unequip.png",
	},
	"ui_resource_delta": {
		"cue_id": "vfx_placeholder_resource_delta",
		"texture_path": "res://art/overworld/runtime/vfx/resource_delta.png",
	},
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var asset_contract := _asset_contract()
	if not bool(asset_contract.get("ok", false)):
		return _fail("Action-feedback asset contract failed: %s" % JSON.stringify(asset_contract), original_window_size)
	var rows := []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			return _fail("Action-feedback VFX failed at %s: %s" % [viewport_size, JSON.stringify(row)], original_window_size)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "asset_contract": asset_contract, "rows": rows})])
	get_tree().quit(0)

func _fail(message: String, original_window_size: Vector2i) -> void:
	get_window().size = original_window_size
	push_error(message)
	get_tree().quit(1)

func _run_viewport(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var active_session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var authority_before: Dictionary = active_session.to_dict()
	var cases := []
	for event_id_value in EXPECTED_ASSETS:
		var event_id := String(event_id_value)
		var expected: Dictionary = EXPECTED_ASSETS[event_id]
		var normal: Dictionary = await _run_presentation(shell, event_id, String(expected.get("cue_id", "")), true, true)
		var reduced: Dictionary = await _run_presentation(shell, event_id, _fallback_cue_id(event_id), false, false)
		var missing: Dictionary = await _run_presentation(shell, event_id, "vfx_missing_action_feedback", false, true)
		cases.append({"event_id": event_id, "normal": normal, "reduced": reduced, "missing": missing})
		if not bool(normal.get("ok", false)) or not bool(reduced.get("ok", false)) or not bool(missing.get("ok", false)):
			return await _finish(shell, {"ok": false, "failure": "presentation_case", "cases": cases})
	var authority_after: Dictionary = active_session.to_dict()
	return await _finish(shell, {
		"ok": authority_after == authority_before,
		"viewport_size": viewport_size,
		"cases": cases,
		"session_authority_exact": authority_after == authority_before,
		"save_version": int(authority_after.get("save_version", -1)),
	})

func _run_presentation(shell: Node, event_id: String, selected_vfx_cue_id: String, expects_imported: bool, allows_large_motion: bool) -> Dictionary:
	var payload := _presentation_payload(event_id, selected_vfx_cue_id, allows_large_motion)
	var method := "present_resource_delta_presentation" if event_id == "ui_resource_delta" else ("present_artifact_acquired_presentation" if event_id == "artifact_acquired" else "present_artifact_slot_presentation")
	var snapshot: Dictionary = shell.call(method, payload)
	await get_tree().process_frame
	var validation: Dictionary = shell.validation_snapshot()
	var key := "resource_delta_presentation" if event_id == "ui_resource_delta" else ("artifact_acquired_presentation" if event_id == "artifact_acquired" else "artifact_slot_presentation")
	snapshot = validation.get(key, {}).duplicate(true) if validation.get(key, {}) is Dictionary else {}
	var artifact_domain := event_id.begins_with("artifact_")
	var row := shell.get_node_or_null("%ArtifactActionCueRow") as Control if artifact_domain else shell.get_node_or_null("%ResourceDeltaCueRow") as Control
	var icon := shell.get_node_or_null("%ArtifactActionCueIcon") as TextureRect if artifact_domain else shell.get_node_or_null("%ResourceDeltaCueIcon") as TextureRect
	var label := shell.get_node_or_null("%ArtifactActionCue") as Label if artifact_domain else shell.get_node_or_null("%ResourceDeltaCue") as Label
	var host := shell.get_node_or_null("%CueChip") as Control if artifact_domain else shell.get_node_or_null("%ResourceChip") as Control
	var vfx: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	var expected: Dictionary = EXPECTED_ASSETS.get(event_id, {})
	var row_rect := row.get_global_rect() if row != null else Rect2()
	var icon_rect := icon.get_global_rect() if icon != null else Rect2()
	var label_rect := label.get_global_rect() if label != null else Rect2()
	var host_rect := host.get_global_rect() if host != null else Rect2()
	var geometry_exact := (
		row != null and icon != null and label != null and host != null
		and row.is_visible_in_tree() and label.is_visible_in_tree()
		and row_rect.size.x > 0.0 and row_rect.size.y > 0.0
		and label_rect.size.x > 0.0 and label_rect.size.y > 0.0
		and row_rect.grow(0.5).encloses(label_rect)
		and host_rect.grow(0.5).encloses(row_rect)
	)
	if expects_imported:
		geometry_exact = geometry_exact and icon.is_visible_in_tree() and icon_rect.size.x > 0.0 and icon_rect.size.y > 0.0 and row_rect.grow(0.5).encloses(icon_rect)
	else:
		geometry_exact = geometry_exact and not icon.visible and icon.texture == null
	var exact: bool = (
		bool(snapshot.get("active", false))
		and bool(snapshot.get("visible", false))
		and String(snapshot.get("event_id", "")) == event_id
		and Array(snapshot.get("selected_vfx_cue_ids", [])) == [selected_vfx_cue_id]
		and String(snapshot.get("text", "")) == _expected_text(event_id)
		and String(snapshot.get("tooltip_text", "")) == "Action feedback fixture"
		and bool(vfx.get("imported", false)) == expects_imported
		and bool(vfx.get("icon_visible", false)) == expects_imported
		and String(vfx.get("fallback", "")) == ("" if expects_imported else "text_only_feedback")
		and String(vfx.get("texture_path", "")) == (String(expected.get("texture_path", "")) if expects_imported else "")
		and String(vfx.get("render_mode", "")) == ("action_feedback_icon" if expects_imported else "")
		and (vfx.get("texture_size", {}) == {"x": 512, "y": 512} if expects_imported else not vfx.has("texture_size"))
		and geometry_exact
	)
	if event_id == "artifact_acquired":
		shell.dismiss_artifact_acquired_presentation(false)
	elif event_id == "ui_resource_delta":
		shell.dismiss_resource_delta_presentation()
	return {
		"ok": exact,
		"event_id": event_id,
		"selected_vfx_cue_id": selected_vfx_cue_id,
		"expects_imported": expects_imported,
		"geometry_exact": geometry_exact,
		"vfx_asset": vfx.duplicate(true),
		"row_rect": row_rect,
		"icon_rect": icon_rect,
		"label_rect": label_rect,
		"host_rect": host_rect,
	}

func _presentation_payload(event_id: String, selected_vfx_cue_id: String, allows_large_motion: bool) -> Dictionary:
	var common := {
		"serial": 1,
		"event_id": event_id,
		"result_message": "Action feedback fixture",
		"selected_playback_policy": "queue_resolved",
		"selected_blocking_policy": "nonblocking",
		"selected_vfx_cue_ids": [selected_vfx_cue_id],
		"allows_large_motion": allows_large_motion,
		"duration_ms": 520,
	}
	match event_id:
		"artifact_acquired":
			common.merge({"cue_id": "cue_artifact_acquired", "action_id": "collect_artifact", "artifact_id": "artifact_trailsinger_boots", "artifact_name": "Trailsinger Boots", "placement_id": "action_feedback_fixture", "tile": {"x": 2, "y": 1}, "location": "equipped", "slot": "boots", "post_action_recap": {}, "selected_blocking_policy": "input_blocking_timeout" if allows_large_motion else "nonblocking_reduced_motion", "blocks_input": allows_large_motion}, true)
		"artifact_equipped":
			common.merge({"cue_id": "cue_artifact_equipped", "action_id": "equip_artifact:artifact_trailsinger_boots", "artifact_id": "artifact_trailsinger_boots", "artifact_name": "Trailsinger Boots", "slot": "boots"})
		"artifact_unequipped":
			common.merge({"cue_id": "cue_artifact_unequipped", "action_id": "unequip_artifact:boots", "artifact_id": "artifact_trailsinger_boots", "artifact_name": "Trailsinger Boots", "slot": "boots"})
		"ui_resource_delta":
			common.merge({"cue_id": "cue_ui_resource_delta", "action_id": "collect_resource", "placement_id": "action_feedback_fixture", "tile": {"x": 2, "y": 1}, "deltas": [{"resource_id": "wood", "before": 10, "after": 15, "delta": 5}], "post_action_recap": {}})
	return common

func _expected_text(event_id: String) -> String:
	match event_id:
		"artifact_acquired": return "Recovered: Trailsinger Boots • Boots"
		"artifact_equipped": return "Equipped: Trailsinger Boots • Boots"
		"artifact_unequipped": return "Stowed: Trailsinger Boots • Boots"
		"ui_resource_delta": return "Wood +5"
	return ""

func _fallback_cue_id(event_id: String) -> String:
	match event_id:
		"artifact_acquired": return "artifact_badge_added"
		"artifact_equipped": return "slot_badge_added"
		"artifact_unequipped": return "slot_badge_removed"
		"ui_resource_delta": return "resource_delta_static"
	return ""

func _asset_contract() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	var cues: Dictionary = parsed.get("cues", {}) if parsed is Dictionary and parsed.get("cues", {}) is Dictionary else {}
	var source := _load_png_image(SOURCE_PATH)
	var hashes := []
	var rows := []
	for event_id_value in EXPECTED_ASSETS:
		var event_id := String(event_id_value)
		var expected: Dictionary = EXPECTED_ASSETS[event_id]
		var cue_id := String(expected.get("cue_id", ""))
		var texture_path := String(expected.get("texture_path", ""))
		var spec: Dictionary = cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}
		var image := _load_png_image(texture_path)
		var hash := FileAccess.get_sha256(texture_path)
		hashes.append(hash)
		rows.append({
			"event_id": event_id,
			"cue_id": cue_id,
			"texture_path": texture_path,
			"ok": String(spec.get("event_id", "")) == event_id and String(spec.get("texture_path", "")) == texture_path and String(spec.get("render_mode", "")) == "action_feedback_icon" and image != null and image.get_size() == Vector2i(512, 512) and image.detect_alpha() != Image.ALPHA_NONE and hash != "",
			"sha256": hash,
		})
	var rows_exact := rows.all(func(row): return bool(row.get("ok", false)))
	return {
		"ok": source != null and source.get_size() == Vector2i(1536, 1024) and source.detect_alpha() != Image.ALPHA_NONE and rows_exact and hashes.size() == 4 and hashes.duplicate().reduce(func(unique, hash): return unique + ([] if hash in unique else [hash]), []).size() == 4,
		"source_size": source.get_size() if source != null else Vector2i.ZERO,
		"source_alpha": source.detect_alpha() if source != null else Image.ALPHA_NONE,
		"rows": rows,
		"distinct_hash_count": hashes.duplicate().reduce(func(unique, hash): return unique + ([] if hash in unique else [hash]), []).size(),
	}

func _load_png_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return image

func _finish(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	return result
