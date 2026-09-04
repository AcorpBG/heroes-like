extends Node

const REPORT_ID := "OVERWORLD_LANDMARK_READABILITY_RUNTIME_REPORT"
const TOWN_ASSET_IDS := [
	"town_faction_embercourt",
	"town_faction_mireclaw",
	"town_faction_sunvault",
	"town_faction_thornwake",
	"town_faction_brasshollow",
	"town_faction_veilmourn",
	"town_identity_riverwatch",
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	SessionState.reset_session()
	var session = ScenarioFactory.create_session("prismhearth-watch", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	if session == null:
		return _fail("Could not create authored readability fixture.")
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null:
		return _fail("Overworld map view was unavailable.")
	var authority_before: Dictionary = session.to_dict()
	var scale_rows := _semantic_scale_rows(map_view)
	var town_rows := _town_rows(map_view)
	var click_routing_exact := _town_click_routing_exact(map_view)
	var authority_exact := session.to_dict() == authority_before
	var semantic_scale_exact := _semantic_scale_exact(scale_rows)
	var town_scale_exact := _town_scale_exact(town_rows)
	if not semantic_scale_exact or not town_scale_exact or not click_routing_exact or not authority_exact:
		shell.queue_free()
		return _fail("Readability contract failed: %s" % JSON.stringify({
			"semantic_scale_exact": semantic_scale_exact,
			"town_scale_exact": town_scale_exact,
			"click_routing_exact": click_routing_exact,
			"authority_exact": authority_exact,
			"scale_rows": scale_rows,
			"town_rows": town_rows,
		}))
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"scale_hierarchy_model": "classic_readable_semantic_landmark_bands_v6",
		"semantic_scale_exact": true,
		"interactive_silhouette_exact": true,
		"decoration_subordinate_exact": true,
		"town_asset_count": town_rows.size(),
		"town_painted_bounds_exact": true,
		"town_click_routing_exact": true,
		"session_authority_exact": true,
		"scale_rows": scale_rows,
		"town_rows": town_rows,
	})])
	shell.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)

func _semantic_scale_rows(map_view: Node) -> Array:
	var rows := []
	var cases := [
		["decoration", "mapobj_withered_rootgate_marker", "decoration", {"primary_class": "decoration", "footprint_tier": "micro"}, Vector2i.ONE],
		["artifact", "artifact_field_trailsinger_boots", "artifact", {"primary_class": "handheld_artifact", "footprint_tier": "micro"}, Vector2i.ONE],
		["map_object", "mapobj_withered_rootgate_marker", "map_object", {"primary_class": "map_object", "footprint_tier": "micro"}, Vector2i.ONE],
		["pickup", "lumber_wagon", "pickup", {"primary_class": "pickup", "footprint_tier": "micro"}, Vector2i.ONE],
		["waypoint", "mapobj_withered_rootgate_marker", "transit_object", {"primary_class": "transit_route_object", "footprint_tier": "small"}, Vector2i.ONE],
		["service", "mapobj_contract_scribe_booth", "repeatable_service", {"primary_class": "interactable_site", "footprint_tier": "small"}, Vector2i.ONE],
		["encounter", "mapobj_withered_rootgate_marker", "encounter", {"primary_class": "neutral_encounter", "footprint_tier": "micro"}, Vector2i.ONE],
		["blocker", "mapobj_withered_rootgate_marker", "blocker", {"primary_class": "decoration", "footprint_tier": "small"}, Vector2i.ONE],
		["landmark", "mapobj_withered_rootgate_marker", "scenario_objective", {"primary_class": "scenario_objective", "footprint_tier": "micro"}, Vector2i.ONE],
		["multi_tile_service", "mapobj_contract_scribe_booth", "repeatable_service", {"primary_class": "interactable_site", "footprint_tier": "medium"}, Vector2i(2, 2)],
		["large_service", "mapobj_contract_scribe_booth", "repeatable_service", {"primary_class": "interactable_site", "footprint_tier": "large"}, Vector2i(3, 2)],
	]
	for case_value in cases:
		var payload: Dictionary = map_view.call("validation_object_sprite_scale_payload", case_value[1], case_value[2], case_value[4], case_value[3])
		rows.append({
			"id": case_value[0],
			"extent_tiles": float(payload.get("visible_extent_tiles", 0.0)),
			"interactive_silhouette": bool(payload.get("interactive_silhouette", false)),
			"silhouette_model": String(payload.get("interactive_silhouette_model", "")),
			"visible_alpha": float(payload.get("visible_modulate_alpha", 0.0)),
			"painted_bounds": bool(payload.get("uses_painted_bounds", false)),
			"cache_exact": bool(payload.get("cache_repeat_exact", false)),
		})
	var hero: Dictionary = map_view.call("validation_hero_draw_layout", Vector2i(7, 4), true)
	rows.append({
		"id": "hero",
		"extent_tiles": float(hero.get("sprite_extent_fraction", 0.0)),
		"interactive_silhouette": true,
		"silhouette_model": String(hero.get("sprite_silhouette_model", "")),
		"visible_alpha": 1.0,
		"painted_bounds": true,
		"cache_exact": true,
	})
	return rows

func _semantic_scale_exact(rows: Array) -> bool:
	var expected := {
		"decoration": 0.46,
		"artifact": 0.58,
		"map_object": 0.62,
		"pickup": 0.68,
		"waypoint": 0.78,
		"service": 0.82,
		"hero": 0.86,
		"encounter": 0.88,
		"blocker": 0.92,
		"landmark": 0.94,
		"multi_tile_service": 1.22,
		"large_service": 1.35,
	}
	for row_value in rows:
		var row: Dictionary = row_value
		var row_id := String(row.get("id", ""))
		if not expected.has(row_id) or not is_equal_approx(float(row.get("extent_tiles", 0.0)), float(expected[row_id])):
			return false
		if not bool(row.get("painted_bounds", false)) or not bool(row.get("cache_exact", false)):
			return false
		var should_outline := row_id not in ["decoration", "blocker"]
		if bool(row.get("interactive_silhouette", false)) != should_outline:
			return false
		if should_outline and String(row.get("silhouette_model", "")) != "eight_direction_alpha_silhouette_outline":
			return false
		if row_id == "decoration" and not is_equal_approx(float(row.get("visible_alpha", 0.0)), 0.82):
			return false
	return rows.size() == expected.size()

func _town_rows(map_view: Node) -> Array:
	var rows := []
	for asset_id in TOWN_ASSET_IDS:
		var payload: Dictionary = map_view.call("validation_town_sprite_scale_payload", asset_id)
		rows.append({
			"asset_id": asset_id,
			"painted_width_tiles": float(payload.get("painted_width_tiles", 0.0)),
			"painted_height_tiles": float(payload.get("painted_height_tiles", 0.0)),
			"logical_footprint": payload.get("logical_footprint", {}),
			"visual_footprint": payload.get("visual_footprint", {}),
			"grounded": bool(payload.get("painted_bottom_grounded_exact", false)),
			"contained": bool(payload.get("sprite_silhouette_contained_in_footprint", false)),
		})
	return rows

func _town_scale_exact(rows: Array) -> bool:
	if rows.size() != TOWN_ASSET_IDS.size():
		return false
	for row_value in rows:
		var row: Dictionary = row_value
		if not is_equal_approx(float(row.get("painted_width_tiles", 0.0)), 2.90) \
			or not is_equal_approx(float(row.get("painted_height_tiles", 0.0)), 3.72) \
			or row.get("logical_footprint", {}) != {"width": 3, "height": 2} \
			or row.get("visual_footprint", {}) != {"width": 3, "height": 4} \
			or not bool(row.get("grounded", false)) \
			or not bool(row.get("contained", false)):
			return false
	return true

func _town_click_routing_exact(map_view: Node) -> bool:
	var profiles: Array = map_view.call("validation_town_presentation_profiles")
	if profiles.is_empty():
		return false
	for profile_value in profiles:
		var profile: Dictionary = profile_value
		var placement_id := String(profile.get("town_placement_id", ""))
		for cell_value in profile.get("footprint_cells", []):
			var cell: Dictionary = cell_value
			if not bool(cell.get("in_bounds", false)):
				continue
			var clicked_tile := Vector2i(int(cell.get("x", -1)), int(cell.get("y", -1)))
			var selection: Dictionary = map_view.call("town_footprint_selection", clicked_tile)
			if String(selection.get("town_placement_id", "")) != placement_id \
				or bool(selection.get("is_entry_tile", false)) != bool(cell.get("is_entry_tile", false)):
				return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
