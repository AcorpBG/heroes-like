extends Node

const SCENARIO_ID := "ninefold-confluence"
const THIRD_HEARTHS_SCENARIO_ID := "third-hearths-confluence"
const THIRD_HEARTHS_ATLAS_PATH := "res://art/overworld/runtime/objects/towns/identity_atlases/third_hearths_atlas.png"
const HORIZON_CITADELS_ATLAS_PATH := "res://art/overworld/runtime/objects/towns/identity_atlases/horizon_citadels_atlas.png"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const TOWN_VISUAL_EXTENT_CAP_TILES := 3.72
const TOWN_VISUAL_WIDTH_CAP_TILES := 2.90
const TOWN_EXTENT_FRACTION := 1.24
const TOWN_GROUND_CLEARANCE_TILES := 0.18
const EXPECTED_TOWN_ASSETS := {
	"town_riverwatch": "town_identity_riverwatch",
	"town_duskfen": "town_identity_duskfen",
	"town_blackfen_gate": "town_identity_blackfen_gate",
	"town_highwater_keep": "town_identity_highwater_keep",
	"town_murkward_ford": "town_identity_murkward_ford",
	"town_reedbarrow_ferry": "town_identity_reedbarrow_ferry",
	"town_nightglass_redoubt": "town_identity_nightglass_redoubt",
	"town_prismhearth": "town_identity_prismhearth",
	"town_halo_spire": "town_identity_halo_spire",
	"town_thornwake_graftroot_caravan": "town_identity_thornwake_graftroot_caravan",
	"town_brasshollow_orevein_gantry": "town_identity_brasshollow_orevein_gantry",
	"town_veilmourn_bellwake_harbor": "town_identity_veilmourn_bellwake_harbor",
	"town_thornwake_rootgate_nursery": "town_identity_thornwake_rootgate_nursery",
	"town_brasshollow_clauseworks_depot": "town_identity_brasshollow_clauseworks_depot",
	"town_veilmourn_fogchart_mooring": "town_identity_veilmourn_fogchart_mooring",
	"town_cinderlock_bastion": "town_identity_cinderlock_bastion",
	"town_dawnmirror_observatory": "town_identity_dawnmirror_observatory",
	"town_briarwheel_enclave": "town_identity_briarwheel_enclave",
	"town_cindercoil_foundry": "town_identity_cindercoil_foundry",
	"town_gloamwake_anchorage": "town_identity_gloamwake_anchorage",
	"town_rainwrit_bastion": "town_identity_rainwrit_bastion",
	"town_hollowreed_sanctuary": "town_identity_hollowreed_sanctuary",
	"town_meridian_choirhold": "town_identity_meridian_choirhold",
	"town_crownroot_refuge": "town_identity_crownroot_refuge",
	"town_blackbell_foundry": "town_identity_blackbell_foundry",
	"town_pale_sounding_harbor": "town_identity_pale_sounding_harbor",
}
const THIRD_HEARTH_OBJECTIVES := {
	"town_cinderlock_bastion": "hold_third_cinderlock",
	"town_dawnmirror_observatory": "claim_third_dawnmirror",
	"town_briarwheel_enclave": "claim_third_briarwheel",
	"town_cindercoil_foundry": "claim_third_cindercoil",
	"town_gloamwake_anchorage": "claim_third_gloamwake",
}
const HORIZON_CITADEL_TOWN_IDS := [
	"town_rainwrit_bastion",
	"town_hollowreed_sanctuary",
	"town_meridian_choirhold",
	"town_crownroot_refuge",
	"town_blackbell_foundry",
	"town_pale_sounding_harbor",
]

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
	var third_hearths := _validate_third_hearth_content()
	if not bool(third_hearths.get("ok", false)):
		_fail("Five-faction third-hearth content failed: %s" % third_hearths)
		return
	var horizon_citadels := _validate_horizon_citadels_content()
	if not bool(horizon_citadels.get("ok", false)):
		_fail("Six Horizon Citadels content failed: %s" % horizon_citadels)
		return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_FACTION_TOWN_SPRITE_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"faction_count": 6,
		"authored_town_count": EXPECTED_TOWN_ASSETS.size(),
		"viewports": [[1280, 720], [1920, 1080]],
		"fallback_asset_id": "frontier_town",
		"rows": rows,
		"third_hearths": third_hearths,
		"horizon_citadels": horizon_citadels,
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
	session.overworld["towns"] = _identity_fixture_towns()
	session = SessionState.set_active_session(session)
	_reveal_town_entries(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var authority_before: Dictionary = session.to_dict()
	var save_clone = SessionStateStore.new_session_data()
	save_clone.from_dict(session.to_dict())
	var save_resume_exact := _town_identity_keys(save_clone.overworld.get("towns", [])) == _town_identity_keys(session.overworld.get("towns", []))
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
			fallback_exact = String(profile.get("faction_id", "")) == "" and String(profile.get("sprite_asset_id", "")) == "frontier_town" and bool(profile.get("uses_default_sprite", false)) and not bool(profile.get("uses_identity_sprite", true)) and not bool(profile.get("uses_faction_sprite", true)) and _town_scale_exact(fallback_scale)
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
		"ok": fallback_exact and restored_exact and containment_exact and save_resume_exact,
		"viewport": [viewport_size.x, viewport_size.y],
		"profile_count": profiles.size(),
		"town_asset_ids": exact_profiles.get("asset_ids", []),
		"visible_asset_exact": exact_profiles.get("visible_asset_exact", false),
		"scale_exact": exact_profiles.get("scale_exact", false),
		"grounding_exact": exact_profiles.get("grounding_exact", false),
		"footprint_authority_exact": exact_profiles.get("footprint_authority_exact", false),
		"owner_pennant_exact": exact_profiles.get("owner_pennant_exact", false),
		"fallback_exact": fallback_exact,
		"restored_exact": restored_exact,
		"save_resume_exact": save_resume_exact,
		"containment_exact": containment_exact,
	}

func _validate_profiles(shell: Node, profiles: Array) -> Dictionary:
	if profiles.size() != EXPECTED_TOWN_ASSETS.size():
		return {"ok": false, "reason": "profile_count", "actual": profiles.size()}
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_color_cue_summary"):
		return {"ok": false, "reason": "color_cue_surface_missing"}
	var color_cues: Dictionary = map_view.call("validation_color_cue_summary")
	var seen_towns: Dictionary = {}
	var seen_assets: Dictionary = {}
	var visible_asset_exact := true
	var scale_exact := true
	var first_scale_failure: Dictionary = {}
	var grounding_exact := true
	var footprint_authority_exact := true
	var owner_pennant_exact := color_cues.has("player_town_color") and color_cues.has("enemy_town_color") and color_cues.has("neutral_town_color")
	for profile_value in profiles:
		if not (profile_value is Dictionary):
			return {"ok": false, "reason": "profile_type"}
		var profile: Dictionary = profile_value
		var town_id := String(profile.get("town_id", ""))
		var expected_asset_id := String(EXPECTED_TOWN_ASSETS.get(town_id, ""))
		var sprite_asset_id := String(profile.get("sprite_asset_id", ""))
		if expected_asset_id == "" or sprite_asset_id != expected_asset_id:
			return {"ok": false, "reason": "asset_identity", "profile": profile}
		if not bool(profile.get("uses_identity_sprite", false)) or bool(profile.get("uses_faction_sprite", true)) or bool(profile.get("uses_default_sprite", true)):
			return {"ok": false, "reason": "fallback_state", "profile": profile}
		var expected_path := THIRD_HEARTHS_ATLAS_PATH if town_id in THIRD_HEARTH_OBJECTIVES else (HORIZON_CITADELS_ATLAS_PATH if town_id in HORIZON_CITADEL_TOWN_IDS else "res://art/overworld/runtime/objects/towns/identity/%s.png" % town_id)
		if String(profile.get("sprite_path", "")) != expected_path or not (load(expected_path) is Texture2D):
			return {"ok": false, "reason": "texture_path", "profile": profile}
		var scale_payload: Dictionary = map_view.call("validation_town_sprite_scale_payload", sprite_asset_id)
		var row_scale_exact := _town_scale_exact(scale_payload)
		if not row_scale_exact and first_scale_failure.is_empty():
			first_scale_failure = {"town_id": town_id, "payload": scale_payload}
		scale_exact = scale_exact and row_scale_exact
		grounding_exact = grounding_exact and bool(scale_payload.get("painted_bottom_grounded_exact", false)) and is_equal_approx(float(scale_payload.get("painted_bottom_clearance_tiles", 0.0)), TOWN_GROUND_CLEARANCE_TILES)
		seen_towns[town_id] = true
		seen_assets[sprite_asset_id] = true
		footprint_authority_exact = footprint_authority_exact and int(profile.get("footprint_width_tiles", 0)) == 3 and int(profile.get("footprint_height_tiles", 0)) == 2 and int(profile.get("visual_footprint_width_tiles", 0)) == 3 and int(profile.get("visual_footprint_height_tiles", 0)) == 4 and String(profile.get("visual_anchor_model", "")) == "three_by_four_entry_center_bottom" and String(profile.get("entry_role", "")) == "bottom_middle_visit_approach" and bool(profile.get("entry_is_visit_tile", false)) and bool(profile.get("non_entry_tiles_blocked", false)) and String(profile.get("presentation_passability", "")) == "entry_only"
		var entry: Dictionary = profile.get("entry_tile", {})
		var presentation: Dictionary = shell.call("validation_tile_presentation", int(entry.get("x", -1)), int(entry.get("y", -1)))
		var art: Dictionary = presentation.get("art_presentation", {})
		var sprite_asset_ids: Array = art.get("sprite_asset_ids", [])
		visible_asset_exact = visible_asset_exact and bool(art.get("uses_asset_sprite", false)) and sprite_asset_id in sprite_asset_ids and not bool(art.get("fallback_procedural_marker", true)) and String(art.get("town_sprite_grounding_model", "")) == "painted_town_contact_edge_without_base_ellipse" and not bool(art.get("town_base_ellipse", true)) and not bool(art.get("town_cast_shadow", true))
	return {
		"ok": seen_towns.size() == EXPECTED_TOWN_ASSETS.size() and seen_assets.size() == EXPECTED_TOWN_ASSETS.size() and visible_asset_exact and scale_exact and grounding_exact and footprint_authority_exact and owner_pennant_exact,
		"asset_ids": seen_assets.keys(),
		"visible_asset_exact": visible_asset_exact,
		"scale_exact": scale_exact,
		"first_scale_failure": first_scale_failure,
		"grounding_exact": grounding_exact,
		"footprint_authority_exact": footprint_authority_exact,
		"owner_pennant_exact": owner_pennant_exact,
	}

func _validate_third_hearth_content() -> Dictionary:
	var session = ScenarioFactory.create_session(THIRD_HEARTHS_SCENARIO_ID, "hard", SessionState.LAUNCH_MODE_SKIRMISH)
	if session == null:
		return {"ok": false, "failure": "scenario_session_missing"}
	var scenario: Dictionary = ContentService.get_scenario(THIRD_HEARTHS_SCENARIO_ID)
	if scenario.is_empty() or scenario.get("towns", []).size() != 6:
		return {"ok": false, "failure": "scenario_contract", "town_count": scenario.get("towns", []).size()}
	var atlas := load(THIRD_HEARTHS_ATLAS_PATH)
	if not (atlas is Texture2D) or atlas.get_width() != 640 or atlas.get_height() != 128:
		return {"ok": false, "failure": "atlas_contract"}
	var rows: Array = []
	var placement_by_town: Dictionary = {}
	for placement_value in session.overworld.get("towns", []):
		if placement_value is Dictionary:
			placement_by_town[String(placement_value.get("town_id", ""))] = placement_value
	for town_id_value in THIRD_HEARTH_OBJECTIVES:
		var town_id := String(town_id_value)
		var town: Dictionary = placement_by_town.get(town_id, {})
		var template: Dictionary = ContentService.get_town(town_id)
		if town.is_empty() or template.is_empty():
			return {"ok": false, "failure": "town_missing", "town_id": town_id}
		town["owner"] = "player"
		session.flags["active_town_placement_id"] = String(town.get("placement_id", ""))
		session.game_state = "town"
		var build_catalog: Array = TownRules.get_build_catalog(session)
		var muster_catalog: Array = TownRules.get_muster_catalog(session)
		var objective_id := String(THIRD_HEARTH_OBJECTIVES[town_id])
		var objective_met: bool = true if objective_id == "hold_third_cinderlock" else ScenarioRules.is_objective_met(session, objective_id, "victory")
		var save_clone = SessionStateStore.new_session_data()
		save_clone.from_dict(session.to_dict())
		var saved_town := _town_by_id(save_clone.overworld.get("towns", []), town_id)
		var save_exact: bool = String(saved_town.get("owner", "")) == "player" and String(save_clone.flags.get("active_town_placement_id", "")) == String(town.get("placement_id", ""))
		var row_ok: bool = template.get("buildable_building_ids", []).size() >= 20 and build_catalog.size() >= 20 and muster_catalog.size() >= 7 and objective_met and save_exact
		rows.append({
			"ok": row_ok,
			"town_id": town_id,
			"faction_id": String(template.get("faction_id", "")),
			"build_catalog_count": build_catalog.size(),
			"muster_catalog_count": muster_catalog.size(),
			"capture_objective_met": objective_met,
			"save_capture_exact": save_exact,
		})
		if not row_ok:
			return {"ok": false, "failure": "town_case", "row": rows[-1]}
	return {"ok": rows.size() == 5, "scenario_id": THIRD_HEARTHS_SCENARIO_ID, "case_count": rows.size(), "rows": rows}

func _town_by_id(towns: Array, town_id: String) -> Dictionary:
	for town_value in towns:
		if town_value is Dictionary and String(town_value.get("town_id", "")) == town_id:
			return town_value
	return {}

func _validate_horizon_citadels_content() -> Dictionary:
	var atlas := load(HORIZON_CITADELS_ATLAS_PATH)
	var scenario: Dictionary = ContentService.get_scenario(SCENARIO_ID)
	var exact_town_ids := HORIZON_CITADEL_TOWN_IDS
	var placed_ids: Array = []
	for placement_value in scenario.get("towns", []):
		if placement_value is Dictionary:
			placed_ids.append(String(placement_value.get("town_id", "")))
	var rows: Array = []
	for town_id in exact_town_ids:
		var template: Dictionary = ContentService.get_town(town_id)
		rows.append({
			"town_id": town_id,
			"exact": not template.is_empty()
				and town_id in placed_ids
				and String(template.get("content_status", "")) == "horizon_citadels_live"
				and EXPECTED_TOWN_ASSETS.has(town_id),
		})
	return {
		"ok": atlas is Texture2D and atlas.get_width() == 768 and atlas.get_height() == 128
			and scenario.get("towns", []).size() == 12
			and rows.all(func(row): return bool(row.get("exact", false))),
		"scenario_id": SCENARIO_ID,
		"case_count": rows.size(),
		"rows": rows,
	}

func _town_scale_exact(payload: Dictionary) -> bool:
	return not payload.is_empty() \
		and payload.get("visual_footprint", {}) == {"width": 3, "height": 4} \
		and payload.get("logical_footprint", {}) == {"width": 3, "height": 2} \
		and float(payload.get("visible_extent_tiles", 0.0)) <= TOWN_VISUAL_EXTENT_CAP_TILES + 0.0001 \
		and is_equal_approx(float(payload.get("visible_extent_fraction_of_footprint_depth", 0.0)), TOWN_EXTENT_FRACTION) \
		and float(payload.get("painted_width_tiles", 0.0)) <= TOWN_VISUAL_WIDTH_CAP_TILES + 0.0001 \
		and float(payload.get("painted_height_tiles", 0.0)) <= TOWN_VISUAL_EXTENT_CAP_TILES + 0.0001 \
		and is_equal_approx(float(payload.get("town_width_cap_tiles", 0.0)), TOWN_VISUAL_WIDTH_CAP_TILES) \
		and is_equal_approx(float(payload.get("town_height_cap_tiles", 0.0)), TOWN_VISUAL_EXTENT_CAP_TILES) \
		and bool(payload.get("town_aspect_preserved", false)) \
		and bool(payload.get("town_vertical_landmark_fit", false)) \
		and float(payload.get("town_to_hero_extent_ratio", 0.0)) > 3.0 \
		and float(payload.get("town_to_largest_other_object_extent_ratio", 0.0)) > 2.0 \
		and is_equal_approx(float(payload.get("source_aspect", 0.0)), float(payload.get("draw_aspect", -1.0))) \
		and bool(payload.get("painted_bottom_grounded_exact", false)) \
		and bool(payload.get("sprite_contained_in_footprint", false)) \
		and String(payload.get("sprite_silhouette_model", "")) == "eight_direction_alpha_silhouette_outline" \
		and float(payload.get("sprite_silhouette_width_px", 0.0)) >= 1.4 \
		and bool(payload.get("sprite_silhouette_contained_in_footprint", false))

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
		"visible_count": EXPECTED_TOWN_ASSETS.size(),
		"explored_count": EXPECTED_TOWN_ASSETS.size(),
		"total_tiles": map_size.x * map_size.y,
	}

func _identity_fixture_towns() -> Array:
	var towns: Array = []
	var town_ids := EXPECTED_TOWN_ASSETS.keys()
	for index in range(town_ids.size()):
		var town_id := String(town_ids[index])
		towns.append({
			"placement_id": "identity_fixture_%s" % town_id,
			"town_id": town_id,
			"x": 6 + (index % 6) * 9,
			"y": 8 + floori(float(index) / 6.0) * 11,
			"owner": ["player", "enemy", "neutral"][index % 3],
		})
	return towns

func _town_identity_keys(towns: Array) -> Array:
	var keys: Array = []
	for town_value in towns:
		if town_value is Dictionary:
			keys.append("%s:%s" % [town_value.get("placement_id", ""), town_value.get("town_id", "")])
	return keys

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
