extends Node

const SCENARIO_ID := "river-pass"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const PENNANT_MODEL := "single_pass_compact_heraldic_cloth_pennant"
const WIDTH_FACTOR := 0.052
const HEIGHT_FACTOR := 0.040
const LEGACY_WIDTH_FACTOR := 0.17
const LEGACY_HEIGHT_FACTOR := 0.12
const VISIBLE_ALPHA := 0.96
const REMEMBERED_ALPHA := 0.68
const EXPECTED_VARIANT_COUNT := 12

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		var row: Dictionary = await _viewport_row(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Town pennant viewport row failed: %s" % row)
			return
	get_window().size = original_window_size
	await get_tree().process_frame
	print("OVERWORLD_TOWN_PENNANT_RUNTIME_REPORT %s" % JSON.stringify({
		"ok": true,
		"scenario_id": SCENARIO_ID,
		"viewports": [[1280, 720], [1920, 1080]],
		"pennant_model": PENNANT_MODEL,
		"variant_count_per_town": EXPECTED_VARIANT_COUNT,
		"painted_area_ratio_to_legacy": (WIDTH_FACTOR * HEIGHT_FACTOR) / (LEGACY_WIDTH_FACTOR * LEGACY_HEIGHT_FACTOR),
		"rows": rows,
		"town_footprints_unchanged": true,
		"town_ownership_unchanged": true,
		"session_authority_unchanged": true,
	}))
	get_tree().quit(0)

func _viewport_row(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal")
	_reveal_all(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var authority_before: Dictionary = session.to_dict()
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("validation_town_owner_pennant_variants"):
		shell.queue_free()
		await get_tree().process_frame
		return {"ok": false, "failure": "map_view_validation_missing"}
	var town_profiles: Array = map_view.call("validation_town_presentation_profiles")
	var expected_owners := ["player", "enemy"]
	var town_rows: Array = []
	for expected_owner in expected_owners:
		var town_profile := _town_profile_for_owner(town_profiles, expected_owner)
		if town_profile.is_empty():
			shell.queue_free()
			await get_tree().process_frame
			return {"ok": false, "failure": "town_owner_missing", "owner": expected_owner}
		var entry_payload: Dictionary = town_profile.get("entry_tile", {})
		var entry_tile := Vector2i(int(entry_payload.get("x", -1)), int(entry_payload.get("y", -1)))
		var variants: Dictionary = map_view.call("validation_town_owner_pennant_variants", entry_tile)
		var presentation: Dictionary = shell.call("validation_tile_presentation", entry_tile.x, entry_tile.y)
		var town_presentation: Dictionary = presentation.get("town_presentation", {})
		var current_pennant: Dictionary = town_presentation.get("owner_pennant", {})
		var row := _assert_town_variants(expected_owner, town_profile, variants, current_pennant)
		town_rows.append(row)
		if not bool(row.get("ok", false)):
			shell.queue_free()
			await get_tree().process_frame
			return {
				"ok": false,
				"failure": "town_variant_contract",
				"owner": expected_owner,
				"town": row,
			}
	var authority_exact := session.to_dict() == authority_before
	var shell_rect: Rect2 = shell.get_global_rect() if shell is Control else Rect2()
	var shell_contained := get_viewport().get_visible_rect().encloses(shell_rect)
	shell.queue_free()
	await get_tree().process_frame
	return {
		"ok": authority_exact and shell_contained and town_rows.size() == expected_owners.size(),
		"viewport": [viewport_size.x, viewport_size.y],
		"town_rows": town_rows,
		"authority_exact": authority_exact,
		"shell_contained": shell_contained,
	}

func _town_profile_for_owner(profiles: Array, owner: String) -> Dictionary:
	for profile_value in profiles:
		if not (profile_value is Dictionary):
			continue
		var profile: Dictionary = profile_value
		if String(profile.get("owner", "")) == owner:
			return profile
	return {}

func _assert_town_variants(
	expected_owner: String,
	town_profile: Dictionary,
	variant_payload: Dictionary,
	current_pennant: Dictionary
) -> Dictionary:
	var variants: Array = variant_payload.get("variants", [])
	var keys: Dictionary = {}
	var all_exact := String(variant_payload.get("model", "")) == PENNANT_MODEL \
		and String(variant_payload.get("live_owner", "")) == expected_owner \
		and int(variant_payload.get("variant_count", 0)) == EXPECTED_VARIANT_COUNT \
		and variants.size() == EXPECTED_VARIANT_COUNT \
		and int(town_profile.get("footprint_width_tiles", 0)) == 3 \
		and int(town_profile.get("footprint_height_tiles", 0)) == 2 \
		and int(town_profile.get("blocked_footprint_cell_count", 0)) + int(town_profile.get("off_map_footprint_cell_count", 0)) == 5 \
		and String(town_profile.get("owner_pennant_model", "")) == PENNANT_MODEL \
		and bool(town_profile.get("owner_pennant_single_pass", false)) \
		and is_equal_approx(float(town_profile.get("owner_pennant_width_factor", 0.0)), WIDTH_FACTOR) \
		and is_equal_approx(float(town_profile.get("owner_pennant_height_factor", 0.0)), HEIGHT_FACTOR)
	for variant_value in variants:
		if not (variant_value is Dictionary):
			all_exact = false
			continue
		var variant: Dictionary = variant_value
		var owner := String(variant.get("owner", ""))
		var remembered := bool(variant.get("remembered", false))
		var assist := bool(variant.get("color_cue_assist", false))
		var key := "%s:%s:%s" % [owner, remembered, assist]
		keys[key] = int(keys.get(key, 0)) + 1
		var expected_shape := "compact_forked"
		var expected_points := 5
		if assist:
			if owner == "player":
				expected_shape = "compact_square_folded"
				expected_points = 5
			elif owner == "enemy":
				expected_shape = "compact_tapered"
				expected_points = 3
			else:
				expected_shape = "compact_diamond"
				expected_points = 4
		var cloth_color: Dictionary = variant.get("cloth_color", {})
		var expected_asset_id := "ownership_pennant_%s" % owner
		var expected_alpha := REMEMBERED_ALPHA if remembered else VISIBLE_ALPHA
		var expected_ratio := (WIDTH_FACTOR * HEIGHT_FACTOR) / (LEGACY_WIDTH_FACTOR * LEGACY_HEIGHT_FACTOR)
		all_exact = all_exact \
			and String(variant.get("model", "")) == PENNANT_MODEL \
			and owner in ["player", "enemy", "neutral"] \
			and String(variant.get("shape_id", "")) == expected_shape \
			and String(variant.get("asset_id", "")) == expected_asset_id \
			and String(variant.get("asset_path", "")) == "res://art/overworld/runtime/objects/ownership_pennants/%s_pennant.png" % owner \
			and bool(variant.get("asset_loaded", false)) \
			and bool(variant.get("asset_contained", false)) \
			and bool(variant.get("asset_mark_contained", false)) \
			and not bool(variant.get("procedural_fallback", true)) \
			and int(variant.get("point_count", 0)) == expected_points \
			and int(variant.get("single_pass_draw_count", 0)) == 1 \
			and int(variant.get("cloth_layer_count", 0)) == 1 \
			and bool(variant.get("cloth_contained", false)) \
			and bool(variant.get("shadow_contained", false)) \
			and bool(variant.get("pole_contained", false)) \
			and bool(variant.get("mark_contained", false)) \
			and (variant.get("fold_line", []) as Array).size() == 2 \
			and (variant.get("highlight_line", []) as Array).size() == 2 \
			and is_equal_approx(float(variant.get("width_factor", 0.0)), WIDTH_FACTOR) \
			and is_equal_approx(float(variant.get("height_factor", 0.0)), HEIGHT_FACTOR) \
			and is_equal_approx(float(variant.get("legacy_width_factor", 0.0)), LEGACY_WIDTH_FACTOR) \
			and is_equal_approx(float(variant.get("legacy_height_factor", 0.0)), LEGACY_HEIGHT_FACTOR) \
			and is_equal_approx(float(variant.get("painted_area_ratio_to_legacy", 1.0)), expected_ratio) \
			and expected_ratio < 0.75 \
			and WIDTH_FACTOR < LEGACY_WIDTH_FACTOR \
			and HEIGHT_FACTOR < LEGACY_HEIGHT_FACTOR \
			and is_equal_approx(float(cloth_color.get("a", 0.0)), expected_alpha)
	var every_variant_once := keys.size() == EXPECTED_VARIANT_COUNT
	for owner in ["player", "enemy", "neutral"]:
		for remembered in [false, true]:
			for assist in [false, true]:
				every_variant_once = every_variant_once and int(keys.get("%s:%s:%s" % [owner, remembered, assist], 0)) == 1
	var current_exact := String(current_pennant.get("model", "")) == PENNANT_MODEL \
		and String(current_pennant.get("owner", "")) == expected_owner \
		and String(current_pennant.get("asset_id", "")) == "ownership_pennant_%s" % expected_owner \
		and bool(current_pennant.get("asset_loaded", false)) \
		and bool(current_pennant.get("asset_contained", false)) \
		and bool(current_pennant.get("asset_mark_contained", false)) \
		and not bool(current_pennant.get("procedural_fallback", true)) \
		and int(current_pennant.get("single_pass_draw_count", 0)) == 1 \
		and int(current_pennant.get("cloth_layer_count", 0)) == 1 \
		and bool(current_pennant.get("cloth_contained", false)) \
		and bool(current_pennant.get("shadow_contained", false)) \
		and bool(current_pennant.get("pole_contained", false))
	return {
		"ok": all_exact and every_variant_once and current_exact,
		"owner": expected_owner,
		"town_placement_id": String(variant_payload.get("town_placement_id", "")),
		"entry_tile": variant_payload.get("entry_tile", {}),
		"variant_count": variants.size(),
		"every_variant_once": every_variant_once,
		"current_exact": current_exact,
		"first_variant": variants[0] if not variants.is_empty() and not all_exact else {},
		"current": current_pennant if not current_exact else {},
		"compact_area_ratio": (WIDTH_FACTOR * HEIGHT_FACTOR) / (LEGACY_WIDTH_FACTOR * LEGACY_HEIGHT_FACTOR),
	}

func _reveal_all(session) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles: Array = []
	var explored_tiles: Array = []
	for _y in range(map_size.y):
		var visible_row: Array = []
		var explored_row: Array = []
		for _x in range(map_size.x):
			visible_row.append(true)
			explored_row.append(true)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": map_size.x * map_size.y,
		"explored_count": map_size.x * map_size.y,
		"total_tiles": map_size.x * map_size.y,
	}

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
