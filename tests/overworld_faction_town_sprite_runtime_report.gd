extends Node

const SCENARIO_ID := "ninefold-confluence"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const TOWN_VISUAL_EXTENT_TILES := 1.36
const TOWN_EXTENT_FRACTION := 0.68
const TOWN_GROUND_CLEARANCE_TILES := 0.18
const EXPECTED_FACTION_ASSETS := {
	"faction_embercourt": "town_faction_embercourt",
	"faction_mireclaw": "town_faction_mireclaw",
	"faction_sunvault": "town_faction_sunvault",
	"faction_thornwake": "town_faction_thornwake",
	"faction_brasshollow": "town_faction_brasshollow",
	"faction_veilmourn": "town_faction_veilmourn",
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row := await _run_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Overworld faction town sprite row failed: %s" % row)
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_FACTION_TOWN_SPRITE_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"faction_count": EXPECTED_FACTION_ASSETS.size(),
		"authored_town_count": 6,
		"viewports": [[1280, 720], [1920, 1080]],
		"fallback_asset_id": "frontier_town",
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
	session = SessionState.set_active_session(session)
	_reveal_town_entries(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var authority_before: Dictionary = session.to_dict()
	if not shell.has_method("validation_town_presentation_profiles") or not shell.has_method("validation_tile_presentation"):
		shell.queue_free()
		return {"ok": false, "failure": "validation_surface_missing"}
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_town_sprite_scale_payload"):
		shell.queue_free()
		return {"ok": false, "failure": "town_scale_surface_missing"}

	var profiles: Array = shell.call("validation_town_presentation_profiles")
	var exact_profiles := _validate_profiles(shell, profiles)
	if not bool(exact_profiles.get("ok", false)):
		shell.queue_free()
		return {"ok": false, "failure": "faction_profiles", "detail": exact_profiles}

	var towns: Array = session.overworld.get("towns", [])
	if towns.is_empty() or not (towns[0] is Dictionary):
		shell.queue_free()
		return {"ok": false, "failure": "fallback_fixture_missing"}
	var first_town: Dictionary = towns[0]
	var original_town_id := String(first_town.get("town_id", ""))
	first_town["town_id"] = "town_missing_faction_sprite_fixture"
	shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame
	var fallback_profiles: Array = shell.call("validation_town_presentation_profiles")
	var fallback_exact := false
	var fallback_scale: Dictionary = map_view.call("validation_town_sprite_scale_payload", "frontier_town")
	for profile_value in fallback_profiles:
		if not (profile_value is Dictionary):
			continue
		var profile: Dictionary = profile_value
		if String(profile.get("town_placement_id", "")) == String(first_town.get("placement_id", "")):
			fallback_exact = String(profile.get("faction_id", "")) == "" and String(profile.get("sprite_asset_id", "")) == "frontier_town" and bool(profile.get("uses_default_sprite", false)) and not bool(profile.get("uses_faction_sprite", true)) and _town_scale_exact(fallback_scale)
			break
	first_town["town_id"] = original_town_id
	shell.call("_refresh")
	await get_tree().process_frame
	await get_tree().process_frame
	var restored_profiles: Array = shell.call("validation_town_presentation_profiles")
	var restored_exact := restored_profiles == profiles and session.to_dict() == authority_before
	var shell_rect: Rect2 = shell.get_global_rect() if shell is Control else Rect2()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var containment_exact: bool = viewport_rect.encloses(shell_rect)
	shell.queue_free()
	await get_tree().process_frame
	return {
		"ok": fallback_exact and restored_exact and containment_exact,
		"viewport": [viewport_size.x, viewport_size.y],
		"profile_count": profiles.size(),
		"faction_asset_ids": exact_profiles.get("asset_ids", []),
		"visible_asset_exact": exact_profiles.get("visible_asset_exact", false),
		"scale_exact": exact_profiles.get("scale_exact", false),
		"grounding_exact": exact_profiles.get("grounding_exact", false),
		"footprint_authority_exact": exact_profiles.get("footprint_authority_exact", false),
		"owner_pennant_exact": exact_profiles.get("owner_pennant_exact", false),
		"fallback_exact": fallback_exact,
		"restored_exact": restored_exact,
		"containment_exact": containment_exact,
	}

func _validate_profiles(shell: Node, profiles: Array) -> Dictionary:
	if profiles.size() != EXPECTED_FACTION_ASSETS.size():
		return {"ok": false, "reason": "profile_count", "actual": profiles.size()}
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_color_cue_summary"):
		return {"ok": false, "reason": "color_cue_surface_missing"}
	var color_cues: Dictionary = map_view.call("validation_color_cue_summary")
	var seen_factions: Dictionary = {}
	var seen_assets: Dictionary = {}
	var visible_asset_exact := true
	var scale_exact := true
	var grounding_exact := true
	var footprint_authority_exact := true
	var owner_pennant_exact := color_cues.has("player_town_color") and color_cues.has("enemy_town_color") and color_cues.has("neutral_town_color")
	for profile_value in profiles:
		if not (profile_value is Dictionary):
			return {"ok": false, "reason": "profile_type"}
		var profile: Dictionary = profile_value
		var faction_id := String(profile.get("faction_id", ""))
		var expected_asset_id := String(EXPECTED_FACTION_ASSETS.get(faction_id, ""))
		var sprite_asset_id := String(profile.get("sprite_asset_id", ""))
		if expected_asset_id == "" or sprite_asset_id != expected_asset_id:
			return {"ok": false, "reason": "asset_identity", "profile": profile}
		if not bool(profile.get("uses_faction_sprite", false)) or bool(profile.get("uses_default_sprite", true)):
			return {"ok": false, "reason": "fallback_state", "profile": profile}
		var expected_path := "res://art/overworld/runtime/objects/towns/factions/%s.png" % faction_id.trim_prefix("faction_")
		if String(profile.get("sprite_path", "")) != expected_path or not (load(expected_path) is Texture2D):
			return {"ok": false, "reason": "texture_path", "profile": profile}
		var scale_payload: Dictionary = map_view.call("validation_town_sprite_scale_payload", sprite_asset_id)
		scale_exact = scale_exact and _town_scale_exact(scale_payload)
		grounding_exact = grounding_exact and bool(scale_payload.get("painted_bottom_grounded_exact", false)) and is_equal_approx(float(scale_payload.get("painted_bottom_clearance_tiles", 0.0)), TOWN_GROUND_CLEARANCE_TILES)
		seen_factions[faction_id] = true
		seen_assets[sprite_asset_id] = true
		footprint_authority_exact = footprint_authority_exact and int(profile.get("footprint_width_tiles", 0)) == 3 and int(profile.get("footprint_height_tiles", 0)) == 2 and String(profile.get("entry_role", "")) == "bottom_middle_visit_approach" and bool(profile.get("entry_is_visit_tile", false)) and bool(profile.get("non_entry_tiles_blocked", false)) and String(profile.get("presentation_passability", "")) == "entry_only"
		var entry: Dictionary = profile.get("entry_tile", {})
		var presentation: Dictionary = shell.call("validation_tile_presentation", int(entry.get("x", -1)), int(entry.get("y", -1)))
		var art: Dictionary = presentation.get("art_presentation", {})
		var sprite_asset_ids: Array = art.get("sprite_asset_ids", [])
		visible_asset_exact = visible_asset_exact and bool(art.get("uses_asset_sprite", false)) and sprite_asset_id in sprite_asset_ids and not bool(art.get("fallback_procedural_marker", true)) and String(art.get("town_sprite_grounding_model", "")) == "town_sprite_settled_without_base_ellipse" and not bool(art.get("town_base_ellipse", true)) and not bool(art.get("town_cast_shadow", true))
	return {
		"ok": seen_factions.size() == EXPECTED_FACTION_ASSETS.size() and seen_assets.size() == EXPECTED_FACTION_ASSETS.size() and visible_asset_exact and scale_exact and grounding_exact and footprint_authority_exact and owner_pennant_exact,
		"asset_ids": seen_assets.keys(),
		"visible_asset_exact": visible_asset_exact,
		"scale_exact": scale_exact,
		"grounding_exact": grounding_exact,
		"footprint_authority_exact": footprint_authority_exact,
		"owner_pennant_exact": owner_pennant_exact,
	}

func _town_scale_exact(payload: Dictionary) -> bool:
	return not payload.is_empty() \
		and is_equal_approx(float(payload.get("visible_extent_tiles", 0.0)), TOWN_VISUAL_EXTENT_TILES) \
		and is_equal_approx(float(payload.get("visible_extent_fraction_of_footprint_depth", 0.0)), TOWN_EXTENT_FRACTION) \
		and is_equal_approx(float(payload.get("town_to_hero_extent_ratio", 0.0)), 2.125) \
		and is_equal_approx(float(payload.get("town_to_largest_other_object_extent_ratio", 0.0)), 1.7) \
		and is_equal_approx(float(payload.get("source_aspect", 0.0)), float(payload.get("draw_aspect", -1.0))) \
		and bool(payload.get("painted_bottom_grounded_exact", false)) \
		and bool(payload.get("sprite_contained_in_footprint", false))

func _reveal_town_entries(session) -> void:
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
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		var x := int(town.get("x", -1))
		var y := int(town.get("y", -1))
		if x >= 0 and y >= 0 and x < map_size.x and y < map_size.y:
			visible_tiles[y][x] = true
			explored_tiles[y][x] = true
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": EXPECTED_FACTION_ASSETS.size(),
		"explored_count": EXPECTED_FACTION_ASSETS.size(),
		"total_tiles": map_size.x * map_size.y,
	}

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
