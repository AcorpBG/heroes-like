extends Node

const GENERATED_GRASTL_ROOT := "res://art/overworld/runtime/terrain_tiles/generated/grastl/frames_64"
const EXPECTED_FRAME_COUNT := 79
const EXPECTED_SOURCE_BASIS := "generated_grastl_replacement_trial_20260503"
const TARGET_VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const ORIGINAL_TILE_BANK_FAMILIES := ["grass", "plains", "forest", "mire", "swamp", "rough", "rock"]
const PROCEDURAL_FALLBACK_FAMILIES := ["water", "coast", "shore", "dirt", "sand", "ash", "lava", "underground", "snow", "frost"]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := []
	var resolved_paths := _expected_frame_paths()
	_assert_all_generated_frames_load(resolved_paths, failures)
	_assert_terrain_grammar_mapping(failures)
	await _assert_overworld_runtime_resolution(failures)

	if not failures.is_empty():
		for failure in failures:
			push_error("Generated grastl runtime asset report: %s" % failure)
		get_tree().quit(1)
		return

	print(JSON.stringify({
		"case_id": "generated_grastl_runtime_asset_report",
		"ok": true,
		"runtime_active": false,
		"reference_only": true,
		"viewport_sizes": TARGET_VIEWPORT_SIZES.map(func(size: Vector2i) -> Dictionary: return {"width": size.x, "height": size.y}),
		"original_tile_bank_families": ORIGINAL_TILE_BANK_FAMILIES,
		"procedural_fallback_families": PROCEDURAL_FALLBACK_FAMILIES,
		"frame_root": GENERATED_GRASTL_ROOT,
		"frame_count": resolved_paths.size(),
		"first_frame": resolved_paths.front(),
		"last_frame": resolved_paths.back(),
		"source_basis": EXPECTED_SOURCE_BASIS,
	}))
	get_tree().quit(0)

func _expected_frame_paths() -> Array:
	var paths := []
	for index in range(EXPECTED_FRAME_COUNT):
		paths.append("%s/00_%02d.png" % [GENERATED_GRASTL_ROOT, index])
	return paths

func _assert_all_generated_frames_load(paths: Array, failures: Array) -> void:
	if paths.size() != EXPECTED_FRAME_COUNT:
		failures.append("expected %d generated grastl frame paths, got %d" % [EXPECTED_FRAME_COUNT, paths.size()])
	for path_value in paths:
		var path := String(path_value)
		if not ResourceLoader.exists(path):
			failures.append("ResourceLoader cannot resolve generated grastl frame: %s" % path)
			continue
		var texture := load(path)
		if not (texture is Texture2D):
			failures.append("generated grastl frame did not load as Texture2D: %s" % path)
			continue
		var image: Image = texture.get_image()
		if image == null or image.get_width() != 64 or image.get_height() != 64:
			failures.append("generated grastl frame is not a 64x64 texture: %s" % path)

func _assert_terrain_grammar_mapping(failures: Array) -> void:
	var grammar: Dictionary = ContentService.get_terrain_grammar()
	var prototype: Dictionary = grammar.get("homm3_local_prototype", {}) if grammar.get("homm3_local_prototype", {}) is Dictionary else {}
	var families: Dictionary = prototype.get("terrain_families", {}) if prototype.get("terrain_families", {}) is Dictionary else {}
	var grass: Dictionary = families.get("grass", {}) if families.get("grass", {}) is Dictionary else {}
	if bool(prototype.get("enabled", true)):
		failures.append("local grastl reference prototype must remain disabled for live rendering")
	if String(grass.get("atlas", "")) != "grastl":
		failures.append("grass family no longer maps to grastl")
	if String(grass.get("asset_root", "")) != GENERATED_GRASTL_ROOT:
		failures.append("grass/grastl asset_root does not point at generated frames: %s" % String(grass.get("asset_root", "")))
	if String(grass.get("asset_root_mode", "")) != "flat_frame_directory":
		failures.append("grass/grastl asset_root_mode must be flat_frame_directory")
	if String(grass.get("runtime_asset_source_basis", "")) != EXPECTED_SOURCE_BASIS:
		failures.append("grass/grastl runtime asset source basis is not recorded")
	if int(grass.get("expected_frame_count", 0)) != EXPECTED_FRAME_COUNT:
		failures.append("grass/grastl expected_frame_count is not 79")

func _assert_overworld_runtime_resolution(failures: Array) -> void:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	SessionState.set_active_session(session)
	OverworldRules.normalize_overworld_state(session)
	var original_window_size: Vector2i = get_window().size
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if not shell.has_method("validation_tile_presentation"):
		failures.append("overworld shell is missing validation_tile_presentation")
		return
	var presentation: Dictionary = shell.call("validation_tile_presentation", 1, 2)
	var terrain: Dictionary = presentation.get("terrain_presentation", {}) if presentation.get("terrain_presentation", {}) is Dictionary else {}
	if not bool(terrain.get("texture_loaded", false)):
		failures.append("overworld grass tile did not load a terrain texture: %s" % JSON.stringify(terrain))
	if bool(terrain.get("uses_homm3_local_prototype", true)) or not bool(terrain.get("uses_original_tile_bank", false)):
		failures.append("overworld grass tile still activates the local grastl reference renderer: %s" % JSON.stringify(terrain))
	if String(terrain.get("rendering_mode", "")) != "original_quiet_tile_bank":
		failures.append("overworld grass tile did not select the original quiet tile bank: %s" % JSON.stringify(terrain))
	if String(terrain.get("homm3_terrain_atlas", "")) != "grastl":
		failures.append("overworld grass tile did not retain the inactive grastl reference metadata: %s" % JSON.stringify(terrain))
	if not String(terrain.get("texture_path", "")).begins_with("res://art/overworld/runtime/terrain_tiles/base/grass_"):
		failures.append("overworld grass tile texture_path does not use the original base bank: %s" % String(terrain.get("texture_path", "")))
	if String(terrain.get("homm3_runtime_asset_source_basis", "")) != EXPECTED_SOURCE_BASIS:
		failures.append("overworld terrain presentation did not report generated grastl source basis")
	if int(terrain.get("homm3_expected_frame_count", 0)) != EXPECTED_FRAME_COUNT:
		failures.append("overworld terrain presentation did not report 79 expected grastl frames")

	var session_authority_before: Dictionary = session.to_dict()
	var route_before := get_tree().current_scene
	var fixture_tile := Vector2i(1, 2)
	var original_map: Array = session.overworld.get("map", []).duplicate(true)
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.has_method("set_map_state") or not map_view.has_method("validation_tile_presentation"):
		failures.append("focused terrain matrix cannot reach the live Overworld map renderer")
		return
	for viewport_size in TARGET_VIEWPORT_SIZES:
		get_window().size = viewport_size
		await get_tree().process_frame
		await get_tree().process_frame
		if get_window().size != viewport_size:
			failures.append("focused terrain viewport did not settle to %s; actual=%s" % [viewport_size, get_window().size])
		for terrain_id in ORIGINAL_TILE_BANK_FAMILIES:
			await _assert_family_runtime(map_view, session, original_map, fixture_tile, String(terrain_id), true, viewport_size, failures)
		for terrain_id in PROCEDURAL_FALLBACK_FAMILIES:
			await _assert_family_runtime(map_view, session, original_map, fixture_tile, String(terrain_id), false, viewport_size, failures)

	var session_authority_after: Dictionary = session.to_dict()
	if session_authority_after != session_authority_before:
		failures.append("focused terrain family/resolution matrix changed exact session, route, object, or save authority; differences=%s" % [_exact_difference_paths(session_authority_before, session_authority_after)])
	if get_tree().current_scene != route_before:
		failures.append("focused terrain family/resolution matrix changed current routed-scene authority")
	get_window().size = original_window_size
	shell.queue_free()
	await get_tree().process_frame

func _assert_family_runtime(map_view: Node, session, original_map: Array, fixture_tile: Vector2i, terrain_id: String, expects_original_tile: bool, viewport_size: Vector2i, failures: Array) -> void:
	var working_map: Array = original_map.duplicate(true)
	working_map[fixture_tile.y][fixture_tile.x] = terrain_id
	map_view.call("set_map_state", session, working_map, OverworldRules.derive_map_size(session), fixture_tile)
	await get_tree().process_frame
	var presentation: Dictionary = map_view.call("validation_tile_presentation", fixture_tile)
	var terrain: Dictionary = presentation.get("terrain_presentation", {}) if presentation.get("terrain_presentation", {}) is Dictionary else {}
	var label := "%s @ %dx%d" % [terrain_id, viewport_size.x, viewport_size.y]
	if String(terrain.get("terrain", "")) != terrain_id:
		failures.append("focused terrain fixture did not present %s: %s" % [label, JSON.stringify(terrain)])
		return
	if bool(terrain.get("uses_homm3_local_prototype", true)):
		failures.append("focused terrain fixture activated the local HoMM3 prototype for %s" % label)
	if String(terrain.get("tile_art_source_basis", "")).find("homm3_extracted") >= 0:
		failures.append("focused terrain fixture reported an extracted runtime source basis for %s" % label)
	if expects_original_tile:
		if not bool(terrain.get("uses_original_tile_bank", false)) or not bool(terrain.get("texture_loaded", false)):
			failures.append("authored terrain family did not load the original tile bank for %s: %s" % [label, JSON.stringify(terrain)])
		if String(terrain.get("rendering_mode", "")) != "original_quiet_tile_bank" or not String(terrain.get("texture_path", "")).begins_with("res://art/overworld/runtime/terrain_tiles/base/"):
			failures.append("authored terrain family did not resolve the shippable base path for %s: %s" % [label, JSON.stringify(terrain)])
	else:
		if bool(terrain.get("uses_original_tile_bank", true)) or bool(terrain.get("texture_loaded", true)) or String(terrain.get("texture_path", "")) != "":
			failures.append("unsupported special terrain did not remain on the procedural fallback for %s: %s" % [label, JSON.stringify(terrain)])
		if String(terrain.get("rendering_mode", "")) != "authored_autotile_layers":
			failures.append("unsupported special terrain did not retain authored grammar fallback for %s: %s" % [label, JSON.stringify(terrain)])

func _exact_difference_paths(before, after, path: String = "$") -> Array:
	var differences := []
	if typeof(before) != typeof(after):
		differences.append("%s:type:%s->%s" % [path, type_string(typeof(before)), type_string(typeof(after))])
		return differences
	if before is Dictionary:
		var keys: Array = before.keys()
		for key in after.keys():
			if key not in keys:
				keys.append(key)
		keys.sort_custom(func(left, right) -> bool: return String(left) < String(right))
		for key in keys:
			if not before.has(key) or not after.has(key):
				differences.append("%s[%s]:presence" % [path, String(key)])
			else:
				differences.append_array(_exact_difference_paths(before[key], after[key], "%s[%s]" % [path, String(key)]))
	elif before is Array:
		if before.size() != after.size():
			differences.append("%s:size:%d->%d" % [path, before.size(), after.size()])
		for index in range(mini(before.size(), after.size())):
			differences.append_array(_exact_difference_paths(before[index], after[index], "%s[%d]" % [path, index]))
	elif before != after:
		differences.append("%s:value:%s->%s" % [path, var_to_str(before), var_to_str(after)])
	if differences.size() > 20:
		return differences.slice(0, 20)
	return differences
