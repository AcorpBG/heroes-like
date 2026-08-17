extends Node

const SCENARIO_ID := "ninefold-confluence"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const EXPECTED_FIELD_ASSET_PREFIX := "artifact_field_"
const EXPECTED_FIELD_SPRITE_DIR := "res://art/overworld/runtime/objects/artifacts/"
const EXPECTED_ICONS := {
	"artifact_trailsinger_boots": "res://art/artifacts/runtime/trailsinger_boots.png",
	"artifact_quarry_tally_rod": "res://art/artifacts/runtime/quarry_tally_rod.png",
	"artifact_warcrest_pennon": "res://art/artifacts/runtime/warcrest_pennon.png",
	"artifact_bastion_gorget": "res://art/artifacts/runtime/bastion_gorget.png",
	"artifact_waymark_compass": "res://art/artifacts/runtime/waymark_compass.png",
	"artifact_milepost_lantern": "res://art/artifacts/runtime/milepost_lantern.png",
	"artifact_tollstone_ring": "res://art/artifacts/runtime/tollstone_ring.png",
	"artifact_mudglass_beads": "res://art/artifacts/runtime/mudglass_beads.png",
	"artifact_choir_tuning_fork": "res://art/artifacts/runtime/choir_tuning_fork.png",
	"artifact_living_bridge_knot": "res://art/artifacts/runtime/living_bridge_knot.png",
	"artifact_pressure_gauge_reliquary": "res://art/artifacts/runtime/pressure_gauge_reliquary.png",
	"artifact_black_sail_compass": "res://art/artifacts/runtime/black_sail_compass.png",
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Overworld artifact pickup icon row failed: %s" % row)
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_ARTIFACT_PICKUP_ICON_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"artifact_count": EXPECTED_ICONS.size(),
		"distinct_field_asset_count": EXPECTED_ICONS.size(),
		"viewports": [[1280, 720], [1920, 1080]],
		"fallback_asset_id": "adventurers_bundle",
		"field_sprite_directory": EXPECTED_FIELD_SPRITE_DIR,
		"inventory_icons_separate": true,
		"rows": rows,
		"save_version": SessionStateStore.SAVE_VERSION,
	}))
	get_tree().quit(0)

func _run_viewport(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}

	var session = ScenarioFactory.create_session(SCENARIO_ID, "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	_configure_fixture(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_tile_presentation"):
		shell.queue_free()
		return {"ok": false, "failure": "validation_surface_missing"}
	var authority_before: Dictionary = session.to_dict()
	var presentation_before := _presentation_rows(map_view, session.overworld.get("artifact_nodes", []))
	var exact := _validate_presentations(presentation_before)
	if not bool(exact.get("ok", false)):
		shell.queue_free()
		return {"ok": false, "failure": "artifact_presentations", "detail": exact}

	var nodes: Array = session.overworld.get("artifact_nodes", [])
	var first_node: Dictionary = nodes[0]
	var original_artifact_id := String(first_node.get("artifact_id", ""))
	first_node["artifact_id"] = "artifact_missing_pickup_icon_fixture"
	shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame
	var fallback_presentation: Dictionary = map_view.call("validation_tile_presentation", Vector2i(int(first_node.get("x", -1)), int(first_node.get("y", -1))))
	var fallback: Dictionary = fallback_presentation.get("artifact_presentation", {})
	var fallback_art: Dictionary = fallback_presentation.get("art_presentation", {})
	var fallback_exact: bool = String(fallback.get("artifact_id", "")) == "artifact_missing_pickup_icon_fixture" \
		and String(fallback.get("icon_path", "")) == "" \
		and String(fallback.get("sprite_asset_id", "")) == "adventurers_bundle" \
		and bool(fallback.get("uses_default_sprite", false)) \
		and not bool(fallback.get("uses_distinct_field_sprite", true)) \
		and not bool(fallback.get("field_sprite_matches_artifact", true)) \
		and not bool(fallback.get("uses_artifact_icon", true)) \
		and "adventurers_bundle" in fallback_art.get("sprite_asset_ids", [])

	first_node["artifact_id"] = original_artifact_id
	shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame
	var presentation_restored := _presentation_rows(map_view, session.overworld.get("artifact_nodes", []))
	var restored_exact: bool = presentation_restored == presentation_before and session.to_dict() == authority_before
	var shell_rect: Rect2 = shell.get_global_rect() if shell is Control else Rect2()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var containment_exact := viewport_rect.encloses(shell_rect)
	shell.queue_free()
	await get_tree().process_frame
	return {
		"ok": fallback_exact and restored_exact and containment_exact,
		"viewport": [viewport_size.x, viewport_size.y],
		"artifact_count": presentation_before.size(),
		"artifact_ids": exact.get("artifact_ids", []),
		"field_asset_ids": exact.get("field_asset_ids", []),
		"transparent_field_sprites": exact.get("transparent_field_sprites", false),
		"visible_count": exact.get("visible_count", 0),
		"remembered_count": exact.get("remembered_count", 0),
		"grounding_exact": exact.get("grounding_exact", false),
		"fallback_exact": fallback_exact,
		"restored_exact": restored_exact,
		"containment_exact": containment_exact,
	}

func _presentation_rows(map_view: Node, nodes: Array) -> Array:
	var rows: Array = []
	for node_value in nodes:
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		rows.append(map_view.call("validation_tile_presentation", Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))))
	return rows

func _validate_presentations(rows: Array) -> Dictionary:
	if rows.size() != EXPECTED_ICONS.size():
		return {"ok": false, "reason": "presentation_count", "actual": rows.size()}
	var seen_artifact_ids: Dictionary = {}
	var seen_field_asset_ids: Dictionary = {}
	var visible_count := 0
	var remembered_count := 0
	var grounding_exact := true
	for row_value in rows:
		if not (row_value is Dictionary):
			return {"ok": false, "reason": "presentation_type"}
		var row: Dictionary = row_value
		var artifact: Dictionary = row.get("artifact_presentation", {})
		var art: Dictionary = row.get("art_presentation", {})
		var artifact_id := String(artifact.get("artifact_id", ""))
		var expected_path := String(EXPECTED_ICONS.get(artifact_id, ""))
		var expected_asset_id := "artifact_icon_%s" % artifact_id.trim_prefix("artifact_")
		var expected_field_asset_id := "%s%s" % [EXPECTED_FIELD_ASSET_PREFIX, artifact_id.trim_prefix("artifact_")]
		var expected_field_path := "%s%s.png" % [EXPECTED_FIELD_SPRITE_DIR, artifact_id.trim_prefix("artifact_")]
		if expected_path == "" or String(artifact.get("icon_asset_id", "")) != expected_asset_id or String(artifact.get("icon_path", "")) != expected_path:
			return {"ok": false, "reason": "icon_path", "row": row}
		if String(artifact.get("sprite_asset_id", "")) != expected_field_asset_id or String(artifact.get("sprite_path", "")) != expected_field_path or bool(artifact.get("uses_artifact_icon", true)) or bool(artifact.get("uses_default_sprite", true)) or not bool(artifact.get("uses_distinct_field_sprite", false)) or not bool(artifact.get("field_sprite_matches_artifact", false)) or not bool(artifact.get("inventory_icon_separate_from_field_sprite", false)):
			return {"ok": false, "reason": "field_sprite_identity", "row": row}
		var field_texture := load(expected_field_path) as Texture2D
		if not (load(expected_path) is Texture2D) or field_texture == null or expected_field_asset_id not in art.get("sprite_asset_ids", []):
			return {"ok": false, "reason": "texture_or_art_payload", "row": row}
		var field_image: Image = field_texture.get_image()
		var transparent_corners := field_image != null \
			and field_image.detect_alpha() != Image.ALPHA_NONE \
			and field_image.get_pixel(0, 0).a <= 0.01 \
			and field_image.get_pixel(field_image.get_width() - 1, 0).a <= 0.01 \
			and field_image.get_pixel(0, field_image.get_height() - 1).a <= 0.01 \
			and field_image.get_pixel(field_image.get_width() - 1, field_image.get_height() - 1).a <= 0.01
		if not transparent_corners:
			return {"ok": false, "reason": "field_sprite_alpha", "row": row}
		if int(artifact.get("footprint_width_tiles", 0)) != 1 or int(artifact.get("footprint_height_tiles", 0)) != 1 or not bool(artifact.get("field_sprite_contained_in_tile", false)) or float(artifact.get("field_sprite_extent_fraction", 2.0)) > 1.0:
			return {"ok": false, "reason": "footprint", "row": row}
		if bool(row.get("visible", false)):
			visible_count += 1
		elif bool(row.get("remembered", false)):
			remembered_count += 1
			if String(art.get("remembered_sprite_treatment", "")) != "ghosted_sprite_with_ground_anchor":
				return {"ok": false, "reason": "remembered_treatment", "row": row}
		else:
			return {"ok": false, "reason": "fog_state", "row": row}
		grounding_exact = grounding_exact \
			and bool(art.get("mapped_sprite_grounding", false)) \
			and String(art.get("mapped_sprite_grounding_model", "")) == "localized_sprite_contact_scuffs" \
			and String(art.get("mapped_sprite_contact_shadow_model", "")) == "localized_sprite_contact_shadow" \
			and not bool(art.get("mapped_sprite_foreground_lip", true)) \
			and not bool(art.get("mapped_sprite_support_stack", true))
		seen_artifact_ids[artifact_id] = true
		seen_field_asset_ids[expected_field_asset_id] = true
	return {
		"ok": seen_artifact_ids.size() == EXPECTED_ICONS.size() and seen_field_asset_ids.size() == EXPECTED_ICONS.size() and visible_count == 12 and remembered_count == 0 and grounding_exact,
		"artifact_ids": seen_artifact_ids.keys(),
		"field_asset_ids": seen_field_asset_ids.keys(),
		"transparent_field_sprites": true,
		"visible_count": visible_count,
		"remembered_count": remembered_count,
		"grounding_exact": grounding_exact,
	}

func _configure_fixture(session) -> void:
	var nodes: Array = []
	var artifact_ids: Array = EXPECTED_ICONS.keys()
	for index in range(artifact_ids.size()):
		nodes.append({
			"placement_id": "artifact_icon_fixture_%02d" % index,
			"artifact_id": String(artifact_ids[index]),
			"x": 2 + (index % 6) if index < 6 else 40 + (index % 6),
			"y": 2 if index < 6 else 40,
			"collected": false,
			"collected_by_faction_id": "",
			"collected_day": 0,
		})
	session.overworld["artifact_nodes"] = nodes
	for key in ["towns", "resource_nodes", "encounters", "map_objects", "decorative_objects", "generated_objects"]:
		session.overworld[key] = []
	var hero: Dictionary = session.overworld.get("hero", {})
	hero["x"] = 0
	hero["y"] = 0
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles: Array = []
	var explored_tiles: Array = []
	for y in range(map_size.y):
		var visible_row: Array = []
		var explored_row: Array = []
		for _x in range(map_size.x):
			visible_row.append(false)
			explored_row.append(false)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	for index in range(nodes.size()):
		var node: Dictionary = nodes[index]
		var x := int(node.get("x", -1))
		var y := int(node.get("y", -1))
		explored_tiles[y][x] = true
		visible_tiles[y][x] = index < 6
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": 6,
		"explored_count": 12,
		"total_tiles": map_size.x * map_size.y,
	}

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
