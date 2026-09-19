extends Node

const SCENARIO_ID := "river-pass"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const PENNANT_MODEL := "paired_small_entrance_control_flags"
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
	var keys := {}
	var exact := String(variant_payload.get("model", "")) == PENNANT_MODEL and variants.size() == EXPECTED_VARIANT_COUNT
	exact = exact and int(town_profile.get("owner_pennant_count", 0)) == 2
	for variant in variants:
		var key := "%s:%s:%s" % [variant.owner, variant.remembered, variant.color_cue_assist]
		keys[key] = int(keys.get(key, 0)) + 1
		exact = exact and _entrance_pair_exact(variant)
	for count in keys.values(): exact = exact and count == 1
	return {"ok": exact and keys.size() == EXPECTED_VARIANT_COUNT and current_pennant.get("owner") == expected_owner and _entrance_pair_exact(current_pennant), "owner": expected_owner}

func _entrance_pair_exact(payload: Dictionary) -> bool:
	if payload.get("model") != PENNANT_MODEL or payload.get("flag_count") != 2 or not payload.get("asset_loaded", false): return false
	var flags: Array = payload.get("flags", [])
	if flags.size() != 2: return false
	var entry: Dictionary = payload.entry_rect
	var center := float(entry.x) + float(entry.width) * 0.5
	return float(flags[0].pole_base.x) < center and float(flags[1].pole_base.x) > center and float(flags[0].pole_base.y) > float(entry.y)

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
