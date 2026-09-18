#!/usr/bin/env python3
"""Object-scale visual inventory and authored/native gameplay regression."""
from contextlib import contextmanager
import shutil
import sys
import tempfile

import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/object-scale-20260917'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = ('scenes/overworld/OverworldMapView.gdc',)
SCRIPT = r'''extends Node
const Select = preload("res://scripts/core/ScenarioSelectRules.gd")
var failures := []
var checks := 0
var metrics := {}
var out := ""
var resolution := Vector2i(1920, 1080)
class Gallery extends Control:
	var cells := []
	var heading := ""
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.16, 0.10))
		draw_string(ThemeDB.fallback_font, Vector2(12, 20), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		for cell in cells:
			var box: Rect2 = cell.box
			draw_texture_rect_region(cell.ground, box, Rect2(0, 0, 512, 512))
			draw_texture_rect(cell.texture, cell.rect, false)
			draw_string(ThemeDB.fallback_font, box.position + Vector2(3, box.size.y - 15), cell.label, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 6, 9)
			draw_string(ThemeDB.fallback_font, box.position + Vector2(3, box.size.y - 3), cell.detail, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 6, 9)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func frame() -> void:
	for i in range(3): await get_tree().process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frame()
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	check(picture.get_size() == resolution, "unexpected capture dimensions")
	picture.save_png(out.path_join(name + ".png"))
func _ready() -> void: call_deferred("run")
func scale_contracts(view, session) -> void:
	var saved: Dictionary = session.to_dict().duplicate(true)
	var definitions: Dictionary = ContentService.load_json("res://content/map_objects.json").duplicate(true)
	var cases := {
		"site_reef_coin_assay":"resource_pickup_gold",
		"site_memory_salt_pan":"resource_pickup_memory_salt",
		"site_peatwax_reed_yard":"resource_pickup_peatwax",
		"site_embergrain_warm_granary":"resource_pickup_embergrain",
		"site_aetherglass_lens_house":"resource_pickup_aetherglass",
		"site_beacon_path_scroll":"beacon_path_scroll",
	}
	for site_id in cases:
		for span in [Vector2i.ONE, Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 3)]:
			var node := {"site_id":site_id, "kind":"reward_reference", "runtime_footprint":{"width":span.x,"height":span.y,"anchor":"bottom_center"}}
			var original := node.duplicate(true)
			var profile: Dictionary = view._resource_object_profile(node)
			check(view._resource_asset_id(node) == cases[site_id], "wrong loose resource identity: " + site_id)
			check(view._semantic_visual_scale_class(profile) == "loose_pickup", "reward inherited mine class: " + site_id)
			check(view._object_profile_footprint(profile) == span, "logical footprint rewritten: " + site_id)
			for tile_size in [36.0, 52.0, 74.0, 104.0]:
				var rect := Rect2(Vector2.ZERO, Vector2(span) * tile_size)
				var scale: Dictionary = view._object_sprite_visual_metrics(rect, profile, tile_size, rect)
				check(is_equal_approx(scale.sprite_extent_tiles, 0.56), "portable extent depends on package footprint: " + site_id)
				check(not scale.uses_multi_tile_visual_cap, "building-sized minimum applied to pickup: " + site_id)
				var texture = view._object_texture_for_asset(cases[site_id])
				var payload: Dictionary = view._object_painted_sprite_draw_payload(cases[site_id], texture, scale.sprite_center, scale.sprite_extent_px)
				check(absf(payload.source_aspect - payload.draw_aspect) < 0.001, "pickup aspect changed")
				var contact: Rect2 = view._portable_object_grounding_rect(payload.draw_rect, scale.sprite_extent_px)
				check(contact.size.x <= tile_size * 0.5601 and contact.size.y <= tile_size * 0.5601, "oversized portable shadow")
				check(absf(contact.position.y + contact.size.y * view._mapped_sprite_ground_center_y_factor("pickup") - payload.draw_rect.end.y) < 0.001, "portable shadow floats off painted base")
				check(view._object_silhouette_width(profile, scale.sprite_extent_px) < 1.0, "pickup outline dominates art")
			check(node == original, "resolver mutated input placement")
		# A real production site using the same ID must retain its structural
		# family, existing footprint, art path and bounded size ladder.
		if site_id == "site_beacon_path_scroll": continue
		var mine := {"site_id":site_id, "kind":"mine"}
		var mine_profile: Dictionary = view._resource_object_profile(mine)
		check(view._semantic_visual_scale_class(mine_profile) == "durable_structure", "real production site shrunk into pickup")
		check(view._resource_asset_id(mine) != cases[site_id], "real mine switched to loose artwork")
	for id in view._artifact_field_asset_ids:
		var profile: Dictionary = view._artifact_object_profile({"artifact_id":id})
		var rect := Rect2(0, 0, 74, 74)
		var scale: Dictionary = view._object_sprite_visual_metrics(rect, profile, 74.0, rect)
		check(is_equal_approx(scale.sprite_extent_tiles, 0.42), "artifact not handheld scale: " + id)
		check(scale.sprite_extent_px >= 24, "artifact unreadable at normal zoom: " + id)
	for family in {"mine":0.82, "scouting_structure":0.78, "scenario_objective":0.94, "encounter":0.88, "blocker":0.92, "decoration":0.46}:
		var expected: Dictionary = {"mine":0.82, "scouting_structure":0.78, "scenario_objective":0.94, "encounter":0.88, "blocker":0.92, "decoration":0.46}
		check(is_equal_approx(view._sprite_extent_fraction(view._default_object_profile(family, Vector2i.ONE), Vector2i.ONE), expected[family]), "unrelated category resized: " + family)
	check(definitions == ContentService.load_json("res://content/map_objects.json"), "authored profiles mutated")
	check(saved == session.to_dict(), "scale resolution altered save/gameplay state")
	check(not JSON.stringify(session.to_dict()).contains("presentation_kind"), "presentation metadata entered save")
	metrics["scale_contracts_preserve_authority"] = true
	var density: Dictionary = ContentService.load_json("res://art/overworld/object_raster_density.json")
	check(density.get("assets", {}).size() == 35, "incomplete low-density correction")
	for key in density.get("assets", {}):
		var row: Dictionary = density.assets[key]
		check(view._object_asset_paths.get(key, "") == row.path, "density mapping not adopted: " + key)
		var texture = view._object_texture_for_asset(key)
		check(texture is AtlasTexture and texture.get_size() == Vector2(192, 192), "48px state still being enlarged: " + key)
		check(view._object_asset_regions.get(key, []) == row.atlas_region, "wrong density atlas region: " + key)

func inspect_catalog(view) -> void:
	var entries := {}
	for id in view._map_object_content_profiles:
		var asset: String = view._map_object_asset_ids.get(id, view._decorative_object_asset_ids.get(id, ""))
		check(not asset.is_empty(), "authored object has no art: " + id)
		if not asset.is_empty(): entries[asset] = view._map_object_content_profiles[id].duplicate(true)
	for site in ContentService.load_json("res://content/resource_sites.json").get("items", []):
		for state in ["", "faction_embercourt"]:
			var node := {"site_id":site.id, "collected_by_faction_id":state}
			var asset: String = view._resource_asset_id(node)
			check(not asset.is_empty(), "site has no art: " + site.id)
			if not asset.is_empty(): entries[asset] = view._resource_object_profile(node)
	for node in metrics.generated_resources:
		entries[node.asset_id] = node.profile
	for id in view._artifact_field_asset_ids:
		entries[view._artifact_field_asset_ids[id]] = view._artifact_object_profile({"artifact_id":id})
	# Include remaining raster states, creature/hero/town reference art and the
	# complete decorative library, not just the current seed's visible subset.
	for asset in view._object_asset_paths:
		if entries.has(asset): continue
		var family := "blocker" if asset.begins_with("decor_") or asset.begins_with("cohesive_") else "encounter"
		entries[asset] = view._default_object_profile(family, Vector2i.ONE)
	var keys := entries.keys()
	keys.sort()
	metrics["catalog_asset_count"] = keys.size()
	if OS.get_environment("OBJECT_SCALE_GALLERY") == "density":
		keys = ContentService.load_json("res://art/overworld/object_raster_density.json").assets.keys()
		keys.sort()
	var gallery := Gallery.new()
	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(gallery)
	var cols := 12
	var rows := 8
	var page_size := cols * rows
	var box_size := Vector2(resolution.x / float(cols), (resolution.y - 28) / float(rows))
	var ground: Texture2D = view._ground_surface.texture
	for page in range(ceili(keys.size() / float(page_size))):
		gallery.cells.clear()
		gallery.heading = "Object art inventory — 74px tile reference, large art fitted into cells; actor/town references are thumbnails — page %d" % (page + 1)
		for index in range(page * page_size, mini((page + 1) * page_size, keys.size())):
			var asset: String = keys[index]
			var texture = view._object_texture_for_asset(asset)
			check(texture is Texture2D, "missing original raster: " + asset)
			if not texture is Texture2D: continue
			var profile: Dictionary = entries[asset]
			var footprint: Vector2i = view._object_profile_footprint(profile)
			var rect := Rect2(Vector2.ZERO, Vector2(footprint) * 74.0)
			var scale: Dictionary = view._object_sprite_visual_metrics(rect, profile, 74.0, rect)
			var payload: Dictionary = view._object_painted_sprite_draw_payload(asset, texture, Vector2.ZERO, scale.sprite_extent_px)
			check(absf(payload.source_aspect - payload.draw_aspect) < 0.001, "distorted original: " + asset)
			var slot := index % page_size
			var box := Rect2(Vector2(slot % cols, slot / cols) * box_size + Vector2(0, 28), box_size)
			var draw_rect: Rect2 = payload.draw_rect
			var fit: float = minf(1.0, minf((box.size.x - 8) / draw_rect.size.x, (box.size.y - 32) / draw_rect.size.y))
			draw_rect.size *= fit
			draw_rect.position = Vector2(box.get_center().x - draw_rect.size.x / 2, box.end.y - 30 - draw_rect.size.y)
			gallery.cells.append({"box":box, "ground":ground, "texture":payload.draw_texture, "rect":draw_rect, "label":asset, "detail":"%s %.2f tiles" % [view._semantic_visual_scale_class(profile), scale.sprite_extent_tiles]})
		gallery.queue_redraw()
		if OS.get_environment("OBJECT_SCALE_GALLERY") in ["1", "density"]: await capture("gallery-%02d" % page)
		else: await get_tree().process_frame
		# Keep the full-library review bounded in RAM on CI and Wine hosts.
		gallery.cells.clear()
		view._object_texture_visible_regions.clear()
		view._object_textures.clear()
	gallery.queue_free()
	await frame()
func run() -> void:
	out = OS.get_environment("BATTLE_READABILITY_OUT")
	var dimensions := OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	resolution = Vector2i(int(dimensions[0]), int(dimensions[1]))
	SettingsService.set_reduced_motion_enabled(true)
	var setup := Select.build_random_map_skirmish_setup_with_retry(
		Select.build_random_map_player_config("medium-random-screenshot-10230", "translated_rmg_template_042_v1", "translated_rmg_profile_042_v1", 4, "land", false, "homm3_medium"),
		"normal", Select.RANDOM_MAP_PLAYER_RETRY_POLICY)
	check(bool(setup.get("ok", false)), "Medium generation failed")
	if not bool(setup.get("ok", false)): return finish()
	var session = Select.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	session = SessionState.set_active_session(session)
	# Source masks are separately checked against every generated record by
	# the exploration regression. Here rendering must preserve the current
	# collision surface, including scenery restored after the original fixture.
	var collision_before := var_to_str(OverworldRules._blocked_tile_index(session)).sha256_text()
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	DisplayServer.window_set_size(resolution)
	get_tree().root.size = resolution
	get_tree().root.content_scale_size = resolution
	await frame()
	var view = shell.get_node("%Map")
	var before: Dictionary = session.to_dict().duplicate(true)
	metrics["terrain_hash"] = var_to_str(session.overworld.map).sha256_text()
	metrics["blocked_hash"] = var_to_str(OverworldRules._blocked_tile_index(session)).sha256_text()
	check(metrics.terrain_hash == "0b87a3d85a5cb77e7b1fe7117215a28ab4383724178079d3dc259249e5836f4d", "Medium terrain changed")
	check(metrics.blocked_hash == collision_before, "opening the map changed Medium collision")
	await capture("generated-gameplay")
	check(before == session.to_dict(), "drawing changed session")
	check(var_to_str(OverworldRules._blocked_tile_index(session)).sha256_text() == collision_before, "drawing changed Medium collision")
	# Same diagnostic viewpoint as the owner-reviewed screenshot, not normal fog.
	for row in session.overworld.fog.explored_tiles: row.fill(true)
	for row in session.overworld.fog.visible_tiles: row.fill(true)
	shell._refresh()
	var focus := Vector2i(36, 36)
	for y in range(20, 52):
		for x in range(20, 52):
			if session.overworld.map[y][x] != session.overworld.map[y][x + 1]: focus = Vector2i(x, y)
	shell.validation_minimap_recenter(focus.x, focus.y)
	await capture("generated-revealed-scale-review")
	var resource_inventory := []
	for node in session.overworld.resource_nodes:
		var profile: Dictionary = view._resource_object_profile(node)
		var footprint: Vector2i = view._object_profile_footprint(profile)
		var rect := Rect2(0, 0, footprint.x * 74, footprint.y * 74)
		var scale: Dictionary = view._object_sprite_visual_metrics(rect, profile, 74.0, rect)
		resource_inventory.append({"id":node.get("id", ""), "site_id":node.get("site_id", ""), "object_id":node.get("object_id", ""), "kind":node.get("kind", ""), "x":node.get("x"), "y":node.get("y"), "profile":profile, "asset_id":view._resource_asset_id(node), "scale_class":view._semantic_visual_scale_class(profile), "extent_tiles":scale.sprite_extent_tiles})
	metrics["generated_resources"] = resource_inventory
	scale_contracts(view, session)
	var authority: Dictionary = session.to_dict().duplicate(true)
	var focused_pickups := 0
	var selected_kinds := {}
	for node in session.overworld.resource_nodes:
		var asset_id: String = view._resource_asset_id(node)
		if asset_id not in ["mapobj_road_writ_purse", "mapobj_memory_salt_jar"] or selected_kinds.has(asset_id): continue
		var tile := Vector2i(int(node.x), int(node.y))
		shell.validation_minimap_recenter(tile.x, tile.y)
		var tile_rect: Rect2 = view._tile_rect(view._board_rect(), tile)
		# Click outside the reduced painted sprite: the entire original tile
		# remains selectable through the real map -> shell signal connection.
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = tile_rect.position + tile_rect.size * Vector2(0.08, 0.08)
		event.pressed = true
		view._gui_input(event)
		event.pressed = false
		view._gui_input(event)
		check(shell._selected_tile == tile, "pickup lost generous tile click target")
		check(view._resource_node_at(tile) == node, "pickup action identity/index changed")
		selected_kinds[asset_id] = true
		focused_pickups += 1
		if focused_pickups == 2: break
	check(focused_pickups == 2, "representative pickup selection cases missing")
	check(authority == session.to_dict(), "selection changed gameplay/save state")
	await inspect_catalog(view)
	var f := FileAccess.open(out.path_join("inventory.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(metrics, "  "))
	f.close()
	shell.queue_free()
	await frame()
	finish()
func finish() -> void:
	MusicAudio.stop_stinger()
	MusicAudio.stop_music("object_scale_probe_teardown")
	print("BATTLE_READABILITY_REPORT " + JSON.stringify({"ok":failures.is_empty(), "checks":checks, "failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


@contextmanager
def preserve_source_packages():
    # Editor builds persist this deterministic seed under res://maps. Preserve
    # any owner-owned copy; release builds use the runner's isolated user://.
    paths = [ROOT / 'maps' / ('medium-amber-ridge-shore-0b79322a' + suffix)
             for suffix in ('.amap', '.ascenario')]
    with tempfile.TemporaryDirectory(prefix='heroes-object-scale-map-backup-') as temporary:
        backups = {}
        for path in paths:
            if path.is_symlink():
                raise ValueError('Refusing symlink map output: ' + str(path))
            if path.exists():
                backup = runner.Path(temporary) / path.name
                shutil.copy2(path, backup)
                backups[path] = backup
        try:
            yield
        finally:
            for path in paths:
                if path in backups:
                    shutil.copy2(backups[path], path)
                    assert path.read_bytes() == backups[path].read_bytes()
                elif path.is_file():
                    path.unlink()


def main():
    if '--platform' in sys.argv:
        import packaged_menu_and_turn_readability_regression as package
        package.ui = sys.modules[__name__]
        return package.main()
    runner.ROOT, runner.OUTPUT, runner.SCRIPT = ROOT, OUTPUT, SCRIPT
    runner.run_probe, runner.probe_environment = run_probe, probe_environment
    with preserve_source_packages():
        return runner.main()


if __name__ == '__main__':
    raise SystemExit(main())
