#!/usr/bin/env python3
"""Reproducible terrain fixtures and real generated Overworld visual acceptance."""
import sys

import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/biome-surface-20260917'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = ('scenes/overworld/OverworldMapView.gdc', 'scenes/overworld/OverworldGroundSurface.gdc')
SCRIPT = r'''extends Node
const Select = preload("res://scripts/core/ScenarioSelectRules.gd")
var failures := []
var checks := 0
var out := ""
var resolution := Vector2i(1920, 1080)
var metrics := {}
func frame() -> void:
	for i in range(3): await get_tree().process_frame
func shader_image(surface, dimensions: Vector2i, rows: Array, fog: Array, serial: int) -> Image:
	surface.sync_lookup(rows, dimensions, serial, fog, serial)
	surface.sync_layout(Rect2(0, 0, 768, 512), Rect2(0, 0, 768, 512), dimensions)
	await frame()
	await RenderingServer.frame_post_draw
	return surface.get_viewport().get_texture().get_image()
func raster_controls(config: Dictionary, atlas: Texture2D) -> void:
	if DisplayServer.get_name() == "headless": return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(768, 512)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var surface = load("res://scenes/overworld/OverworldGroundSurface.gd").new()
	viewport.add_child(surface)
	# A fresh Godot texture import can have no mip chain. Exercise that path,
	# not only this workstation's already imported/mipmapped cache.
	var clean_pixels := atlas.get_image()
	if clean_pixels.is_compressed(): clean_pixels.decompress()
	clean_pixels.clear_mipmaps()
	var clean_atlas := ImageTexture.create_from_image(clean_pixels)
	surface.configure(config, clean_atlas)
	check(surface.texture.get_image().has_mipmaps(), "clean import did not gain bounded terrain detail levels")
	check(not clean_atlas.get_image().has_mipmaps(), "terrain sampling mutated the borrowed original texture")
	check(is_equal_approx(float(surface.material.get_shader_parameter("material_span_tiles")),float(config.material_span_tiles)), "ground ignored manifest sampling span")
	var rows: Array = []
	var fog: Array = []
	for y in range(4):
		rows.append(["grass", "grass", "grass", "water", "water", "water"])
		fog.append([true, true, true, false, false, false])
	var concealed := await shader_image(surface, Vector2i(6, 4), rows, fog, 101)
	for y in range(4):
		for x in range(3, 6): rows[y][x] = "lava"
	var changed_hidden := await shader_image(surface, Vector2i(6, 4), rows, fog, 102)
	check(concealed.get_data() == changed_hidden.get_data(), "unexplored neighbor leaks its biome through blending")
	for row in fog: row.fill(true)
	var revealed := await shader_image(surface, Vector2i(6, 4), rows, fog, 103)
	check(revealed.get_data() != concealed.get_data(), "exploration does not reveal original ground")
	# Compare the real mixed edge to BOTH unmixed painted surfaces, at the same
	# world coordinates; a hard cut or legacy rectangle cannot satisfy this.
	var grass: Array = []
	var lava: Array = []
	for y in range(4):
		grass.append(["grass", "grass", "grass", "grass", "grass", "grass"])
		lava.append(["lava", "lava", "lava", "lava", "lava", "lava"])
	var grass_image := await shader_image(surface, Vector2i(6, 4), grass, fog, 104)
	var lava_image := await shader_image(surface, Vector2i(6, 4), lava, fog, 105)
	var blended_samples := 0
	for y in range(64, 448, 8):
		var value := revealed.get_pixel(384, y)
		if color_distance(value, grass_image.get_pixel(384, y)) > 0.025 and color_distance(value, lava_image.get_pixel(384, y)) > 0.025:
			blended_samples += 1
	check(blended_samples >= 40, "biome edge is not blending both original painted materials")
	for y in range(4):
		for x in range(6):
			var expected := grass_image if x < 3 else lava_image
			check(color_distance(revealed.get_pixel(x * 128 + 64, y * 128 + 64), expected.get_pixel(x * 128 + 64, y * 128 + 64)) < 0.005, "center-of-tile identity lost")
	# Camera translation must move the painting by exactly that pixel offset.
	await shader_image(surface, Vector2i(6, 4), rows, fog, 106)
	surface.sync_layout(Rect2(-32, 0, 768, 512), Rect2(0, 0, 768, 512), Vector2i(6, 4))
	await frame()
	await RenderingServer.frame_post_draw
	var panned := viewport.get_texture().get_image()
	var pan_delta := 0.0
	var pan_total := 0.0
	var pan_samples := 0
	for y in range(0, 512, 2):
		for x in range(0, 736, 2):
			var difference := color_distance(panned.get_pixel(x, y), revealed.get_pixel(x + 32, y))
			pan_delta = maxf(pan_delta, difference)
			pan_total += difference
			pan_samples += 1
	metrics["pan_max_channel_delta"] = pan_delta
	metrics["pan_mean_channel_delta"] = pan_total / pan_samples
	# Different quad widths change floating-point UV interpolation very slightly;
	# permit one 8-bit rounding step, not a visible texture displacement.
	check(pan_delta <= 1.01 / 255.0 and pan_total / pan_samples < 0.00005, "ground painting swims when camera moves")
	# Irregular diagonal coast, an island, a one-cell inlet and a four-way join.
	for y in range(4):
		for x in range(6): rows[y][x] = "sand" if x + y < 5 else "water"
	rows[2][4] = "grass"
	rows[0][1] = "water"
	rows[0][5] = "snow"
	rows[1][5] = "rock"
	var corners := await shader_image(surface, Vector2i(6, 4), rows, fog, 107)
	corners.save_png(out.path_join("shore-island-diagonal-fixture.png"))
	# Check the actual manifest repeat join, not a stale fixed six-tile sample.
	var seamless_rows: Array = []
	var seamless_fog: Array = []
	for y in range(4):
		var repeat_row: Array = []
		var repeat_fog: Array = []
		repeat_row.resize(12)
		repeat_row.fill("grass")
		repeat_fog.resize(12)
		repeat_fog.fill(true)
		seamless_rows.append(repeat_row)
		seamless_fog.append(repeat_fog)
	var seamless := await shader_image(surface, Vector2i(12, 4), seamless_rows, seamless_fog, 108)
	var seam_delta := 0.0
	var interior_delta := 0.0
	var seam_x := roundi(768.0*float(config.material_span_tiles)/12.0)
	for y in range(0, 512, 4):
		seam_delta += color_distance(seamless.get_pixel(seam_x-1, y), seamless.get_pixel(seam_x, y))
		interior_delta += color_distance(seamless.get_pixel(seam_x-5, y), seamless.get_pixel(seam_x-4, y))
	metrics["repeat_seam_mean_delta"] = seam_delta / 128.0
	metrics["repeat_interior_mean_delta"] = interior_delta / 128.0
	check(seam_delta <= interior_delta * 2.0 + 0.64, "painted material repeats leave hard stripe seams")
	metrics["blended_boundary_samples"] = blended_samples
	viewport.queue_free()
	await frame()
func color_distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	check(picture.get_size() == resolution, "unexpected screenshot resolution")
	picture.save_png(out.path_join(name + ".png"))
func resize_view() -> void:
	DisplayServer.window_set_size(resolution)
	get_tree().root.size = resolution
	get_tree().root.content_scale_size = resolution
	for i in range(3): await get_tree().process_frame
func _ready() -> void: call_deferred("run")
func run() -> void:
	out = OS.get_environment("BATTLE_READABILITY_OUT")
	var dimensions := OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	resolution = Vector2i(int(dimensions[0]), int(dimensions[1]))
	SettingsService.set_reduced_motion_enabled(true)
	var setup := Select.build_random_map_skirmish_setup_with_retry(
		Select.build_random_map_player_config("medium-random-screenshot-10230", "translated_rmg_template_042_v1", "translated_rmg_profile_042_v1", 4, "land", false, "homm3_medium"),
		"normal", Select.RANDOM_MAP_PLAYER_RETRY_POLICY)
	check(bool(setup.get("ok", false)), "deterministic Medium generation failed")
	if not bool(setup.get("ok", false)): return finish()
	var session = Select.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	# Rendering must preserve current authoritative collision. The old literal
	# snapshot predates the restored native scenery masks (2026-09-18) and
	# therefore encodes missing blockers, not a valid rendering invariant.
	var collision_before: Dictionary = OverworldRules._blocked_tile_index(session).duplicate(true)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await resize_view()
	var view = shell.get_node("%Map")
	var saved: Dictionary = session.to_dict().duplicate(true)
	metrics["terrain_hash"] = var_to_str(session.overworld.map).sha256_text()
	metrics["blocked_hash"] = var_to_str(OverworldRules._blocked_tile_index(session)).sha256_text()
	check(metrics.terrain_hash == "0b87a3d85a5cb77e7b1fe7117215a28ab4383724178079d3dc259249e5836f4d", "Medium terrain differs from pre-change baseline")
	check(OverworldRules._blocked_tile_index(session) == collision_before, "opening the view changed authoritative collision")
	await capture("generated-gameplay")
	check(saved == session.to_dict(), "gameplay drawing mutated session")
	check(OverworldRules._blocked_tile_index(session) == collision_before, "ground drawing changed authoritative collision")
	var surface = view._ground_surface
	check(surface.configured and surface.visible and surface.missing_terrain_ids.is_empty(), "generated map bypasses original ground")
	metrics["medium_lookup"] = surface.validation_snapshot()
	var uploads: int = surface.map_uploads
	var fog_uploads: int = surface.fog_uploads
	for i in range(120): view._process(1.0 / 120.0)
	shell._refresh()
	await frame()
	check(surface.map_uploads == uploads and surface.fog_uploads == fog_uploads, "idle/ordinary refresh rebuilds lookup textures")
	# Clearly named revealed diagnostic of the SAME map; never sold as live fog.
	for row in session.overworld.fog.explored_tiles: row.fill(true)
	for row in session.overworld.fog.visible_tiles: row.fill(true)
	shell._refresh()
	var focus := Vector2i(36, 36)
	for y in range(20, 52):
		for x in range(20, 52):
			if session.overworld.map[y][x] != session.overworld.map[y][x + 1]: focus = Vector2i(x, y)
	shell.validation_minimap_recenter(focus.x, focus.y)
	await capture("generated-revealed-biome-review")
	check(surface.map_uploads == uploads and surface.fog_uploads == fog_uploads + 1, "fog update unnecessarily rebuilds terrain IDs")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(view.GROUND_MATERIAL_MANIFEST_PATH))
	var atlas: Texture2D = surface.texture
	shell.queue_free()
	for i in range(3): await get_tree().process_frame
	# Material/transition fixture, not a generated gameplay claim.
	var fixture = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var terrains := ["grass", "plains", "forest", "mire", "dirt", "sand", "rough", "rock", "ash", "lava", "underground", "snow", "water", "coast", "shore", "ice"]
	var rows: Array = []
	for y in range(32):
		var row: Array = []
		for x in range(48):
			var index := mini(int(y / 8), 3) * 4 + mini(int(x / 12), 3)
			row.append(terrains[index])
		rows.append(row)
	fixture.overworld.map = rows
	fixture.overworld.map_size = {"width": 48, "height": 32}
	fixture.overworld.terrain_layers = {}
	for key in ["encounters", "towns", "resource_nodes", "artifact_nodes", "map_objects", "resource_sites", "package_block_tiles"]:
		fixture.overworld[key] = []
	fixture.overworld.fog = {}
	OverworldRules.normalize_overworld_state(fixture)
	for row in fixture.overworld.fog.explored_tiles: row.fill(true)
	for row in fixture.overworld.fog.visible_tiles: row.fill(true)
	var map_view = load("res://scenes/overworld/OverworldMapView.gd").new()
	map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_view.large_map_visible_tile_span_override = 48
	add_child(map_view)
	map_view.set_route_preview_enabled(false)
	map_view.set_map_state(fixture, rows, Vector2i(48, 32), Vector2i(-1, -1))
	await capture("material-and-junction-fixture")
	var authority: Dictionary = fixture.to_dict().duplicate(true)
	var start := Time.get_ticks_usec()
	for i in range(3):
		map_view._invalidate_session_static_cache("validation_rebuild")
		await get_tree().process_frame
	metrics["fixture_three_static_rebuild_usec"] = Time.get_ticks_usec() - start
	check(fixture.to_dict() == authority, "fixture rendering mutated authoritative state")
	for terrain_id in config.terrain_slots:
		check(int(config.terrain_slots[terrain_id]) in range(16), "unmapped terrain alias " + terrain_id)
	check(map_view._ground_surface.missing_terrain_ids.is_empty(), "material fixture has missing identities")
	map_view.queue_free()
	await get_tree().process_frame
	await raster_controls(config, atlas)
	# Real native Large setup, not enlarged fixture geometry. The renderer sees
	# its actual terrain and blockers but cannot change the package or save.
	var large_setup := Select.build_random_map_skirmish_setup_with_retry(
		Select.build_random_map_player_config("biome-surface-large-20260917", "translated_rmg_template_042_v1", "translated_rmg_profile_042_v1", 4, "land", false, "homm3_large"),
		"normal", Select.RANDOM_MAP_PLAYER_RETRY_POLICY)
	check(bool(large_setup.get("ok", false)), "representative native Large generation failed")
	if bool(large_setup.get("ok", false)):
		var large_session = Select.start_random_map_skirmish_session_from_setup(large_setup)
		OverworldRules.normalize_overworld_state(large_session)
		var large_before: Dictionary = large_session.to_dict().duplicate(true)
		var large_view = load("res://scenes/overworld/OverworldMapView.gd").new()
		large_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(large_view)
		large_view.set_route_preview_enabled(false)
		var large_size := Vector2i(large_session.overworld.map[0].size(), large_session.overworld.map.size())
		large_view.set_map_state(large_session, large_session.overworld.map, large_size, Vector2i(-1, -1))
		await capture("large-generated-gameplay")
		var large_surface = large_view._ground_surface
		metrics["large_lookup"] = large_surface.validation_snapshot()
		metrics["large_size"] = [large_size.x, large_size.y]
		check(large_size == Vector2i(108, 108), "Large fixture is not native 108x108")
		check(large_surface.configured and large_surface.missing_terrain_ids.is_empty(), "Large uses unmapped ground")
		check(large_surface.last_upload_usec < 250000, "Large lookup upload exceeds 250ms regression guard")
		var large_uploads: int = large_surface.map_uploads
		var large_fog_uploads: int = large_surface.fog_uploads
		for i in range(10):
			large_view.set_map_state(large_session, large_session.overworld.map, large_size, Vector2i(i, i))
		check(large_surface.map_uploads == large_uploads and large_surface.fog_uploads == large_fog_uploads, "Large hover/selection rebuilds map-sized lookup")
		check(large_session.to_dict() == large_before, "Large rendering changes package/save authority")
		large_view.queue_free()
		await frame()
	finish()
func finish() -> void:
	MusicAudio.stop_stinger()
	MusicAudio.stop_music("terrain_probe_teardown")
	print("BATTLE_READABILITY_REPORT " + JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures, "metrics": metrics}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    if '--platform' in sys.argv:
        import packaged_menu_and_turn_readability_regression as package
        package.ui = sys.modules[__name__]
        return package.main()
    runner.ROOT, runner.OUTPUT, runner.SCRIPT = ROOT, OUTPUT, SCRIPT
    runner.run_probe, runner.probe_environment = run_probe, probe_environment
    return runner.main()


if __name__ == '__main__':
    raise SystemExit(main())
