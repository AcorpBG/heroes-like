extends Node

const GENERATED_GRASTL_ROOT := "res://art/overworld/runtime/terrain_tiles/generated/grastl/frames_64"
const EXPECTED_FRAME_COUNT := 79
const EXPECTED_SOURCE_BASIS := "generated_grastl_replacement_trial_20260503"

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
	if String(terrain.get("homm3_terrain_atlas", "")) != "grastl":
		failures.append("overworld grass tile did not resolve the grastl atlas: %s" % JSON.stringify(terrain))
	if not String(terrain.get("texture_path", "")).begins_with(GENERATED_GRASTL_ROOT + "/"):
		failures.append("overworld grass tile texture_path does not use generated grastl frames: %s" % String(terrain.get("texture_path", "")))
	if String(terrain.get("homm3_runtime_asset_source_basis", "")) != EXPECTED_SOURCE_BASIS:
		failures.append("overworld terrain presentation did not report generated grastl source basis")
	if int(terrain.get("homm3_expected_frame_count", 0)) != EXPECTED_FRAME_COUNT:
		failures.append("overworld terrain presentation did not report 79 expected grastl frames")
