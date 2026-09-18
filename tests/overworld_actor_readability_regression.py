#!/usr/bin/env python3
"""Real map/town actors plus the complete original-art roster at gameplay scale."""
import sys

import battle_readability_regression as runner
from overworld_object_scale_regression import preserve_source_packages

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/actor-readability-20260918'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = ('scenes/overworld/OverworldMapView.gdc',
                   'scenes/overworld/OverworldActorStyle.gdc')
SCRIPT = r'''extends Node
const Select = preload("res://scripts/core/ScenarioSelectRules.gd")
const Style = preload("res://scenes/overworld/OverworldActorStyle.gd")
var failures := []
var checks := 0
var metrics := {}
var out := ""
var resolution := Vector2i(1280, 720)
class Gallery extends Control:
	var cells := []
	var view
	var ground: Texture2D
	var terrain_slots := [3, 11]
	var heading := "dark mire / light snow"
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.10, 0.10))
		draw_string(ThemeDB.fallback_font, Vector2(12, 22), "ACTOR INSPECTION - actual 74px map size; " + heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		view._draw_canvas_item = self
		for cell in cells:
			var box: Rect2 = cell.box
			for side in range(2):
				var slot: int = terrain_slots[side]
				var panel := Rect2(box.position + Vector2(side * box.size.x * 0.5, 0), Vector2(box.size.x * 0.5, box.size.y - 24))
				draw_texture_rect_region(ground, panel, Rect2((slot % 4) * 512, (slot / 4) * 512, 512, 512))
				var point := Vector2(panel.get_center().x, panel.end.y - 8)
				view._draw_actor_art(view._actor_sprite_payload(cell.id, cell.texture, point, 74.0), false)
			draw_string(ThemeDB.fallback_font, box.position + Vector2(3, box.size.y - 8), cell.label, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 6, 11)
		view._draw_canvas_item = null
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func frame() -> void:
	for i in range(3): await get_tree().process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frame()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image.get_size() == resolution, "capture dimensions: " + name)
	image.save_png(out.path_join(name + ".png"))
func _ready() -> void: call_deferred("run")
func mount(session):
	SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	DisplayServer.window_set_size(resolution)
	get_tree().root.size = resolution
	get_tree().root.content_scale_size = resolution
	await frame()
	return shell
func roster(view) -> void:
	var manifest: Dictionary = ContentService.load_json("res://art/overworld/actor_sprites.json")
	var assets: Dictionary = manifest.get("assets", {})
	check(assets.size() == 112, "incomplete regenerated actor roster")
	var resolved := {}
	for hero in ContentService.load_json("res://content/heroes.json").items:
		var asset: String = view._hero_sprite_asset_id(hero)
		check(assets.has(asset) and assets[asset].identity_id == hero.id, "wrong hero identity: " + hero.id)
		check(not resolved.has(asset), "shared generic hero: " + hero.id)
		resolved[asset] = true
		var enemy := {"spawned_by_faction_id":hero.faction_id, "enemy_commander_state":{"roster_hero_id":hero.id,"faction_id":hero.faction_id}}
		check(view._hero_sprite_asset_id(view._enemy_commander_hero_template(enemy)) == asset, "enemy commander identity: " + hero.id)
	check(resolved.size() == 66, "hero roster coverage")
	var profiles: Array = ContentService.load_json("res://content/generated_neutral_encounter_profiles.json").profiles
	for profile in profiles:
		var encounter := {"encounter_id":profile.encounter_id, "generated_neutral_profile":profile}
		check(view._encounter_identity_asset_id(encounter) == profile.asset_id, "generated neutral identity: " + profile.encounter_id)
		check(assets.has(profile.asset_id), "neutral lacks regenerated art")
	for id in assets:
		check(view._object_asset_paths.get(id, "") == assets[id].path, "old visual still resolved: " + id)
		var texture = view._object_texture_for_asset(id)
		check(texture is Texture2D, "missing raster: " + id)
		if not texture is Texture2D: continue
		check(texture.get_size() == Vector2(384, 384), "unexpected packaged actor canvas: " + id)
		for extent in [24.0, 36.0, 52.0, 74.0, 104.0]:
			var ground := Vector2(80, 110)
			var payload: Dictionary = view._actor_sprite_payload(id, texture, ground, extent)
			var rect: Rect2 = payload.draw_rect
			check(absf(rect.size.x / rect.size.y - payload.source_aspect) < 0.001, "distorted actor: " + id)
			check(absf(maxf(rect.size.x, rect.size.y) - extent) < 0.001, "canvas padding controls scale: " + id)
			check(absf(rect.end.y - ground.y) < 0.001 and absf(rect.get_center().x - ground.x) < 0.001, "floating actor feet: " + id)
			check(Style.edge_width(extent) >= 1.15 and Style.edge_width(extent) <= 2.0, "unbounded actor edge")
		var painted: Dictionary = view._actor_sprite_payload(id, texture, Vector2.ZERO, 74)
		var mask: Texture2D = view._actor_style.alpha_mask(painted.draw_texture)
		check(mask == view._actor_style.alpha_mask(painted.draw_texture), "per-frame mask allocation")
		var source: Image = painted.draw_texture.get_image()
		var alpha: Image = mask.get_image()
		check(alpha.get_size() == source.get_size(), "mask/source bounds mismatch")
		for y in range(0, source.get_height(), 9):
			for x in range(0, source.get_width(), 9):
				check(is_equal_approx(source.get_pixel(x,y).a, alpha.get_pixel(x,y).a), "mask altered transparency: " + id)
				check(alpha.get_pixel(x,y).r == 1.0 and alpha.get_pixel(x,y).g == 1.0 and alpha.get_pixel(x,y).b == 1.0, "edge depends on source RGB: " + id)
	metrics["heroes"] = resolved.size()
	metrics["neutral_profiles"] = profiles.size()
	metrics["original_sprites"] = assets.size()
	var gallery := Gallery.new()
	gallery.view = view
	gallery.ground = view._ground_surface.texture
	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(gallery)
	var cols := maxi(1, resolution.x / 160)
	var rows := maxi(1, (resolution.y - 32) / 128)
	var per_page := cols * rows
	var cell_size := Vector2(resolution.x / float(cols), (resolution.y - 32) / float(rows))
	var ids := assets.keys()
	ids.sort()
	for page in range(ceili(ids.size() / float(per_page))):
		gallery.cells.clear()
		for index in range(page * per_page, mini(ids.size(), (page + 1) * per_page)):
			var slot := index % per_page
			var id: String = ids[index]
			gallery.cells.append({"id":id, "texture":view._object_texture_for_asset(id), "label":assets[id].accessible_description,
				"box":Rect2(Vector2(slot % cols, slot / cols) * cell_size + Vector2(0,32), cell_size)})
		gallery.queue_redraw()
		await capture("actor-catalog-%02d" % page)
		gallery.terrain_slots = [9, 5]
		gallery.heading = "dark lava / light sand"
		gallery.queue_redraw()
		await capture("actor-catalog-lava-sand-%02d" % page)
		gallery.terrain_slots = [3, 11]
		gallery.heading = "dark mire / light snow"
	gallery.queue_free()
	await frame()
func town_fixture(scenario: String) -> void:
	var session = ScenarioFactory.create_session(scenario, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var shell = await mount(session)
	session = SessionState.ensure_active_session()
	var view = shell.get_node("%Map")
	var town: Dictionary = session.overworld.towns[0]
	for candidate in session.overworld.towns:
		if String(candidate.get("owner", "")) == "player": town = candidate; break
	var entry: Vector2i = view._town_entry_tile(town)
	# Explicit render fixture, not a claimed earned gameplay arrival.
	var hero: Dictionary = session.overworld.player_heroes[0]
	hero.position = {"x":entry.x,"y":entry.y}
	session.overworld.hero_position = hero.position.duplicate()
	session.overworld.hero = hero.duplicate(true)
	shell._refresh()
	shell.validation_minimap_recenter(entry.x, entry.y)
	await frame()
	var before: Dictionary = session.to_dict().duplicate(true)
	var rect := Rect2(0, 0, 74, 74)
	check(view._hero_draw_rect(rect, entry, true) == rect, "town visitor rectangle shrunk")
	var layout: Dictionary = view._hero_draw_layout_payload(rect, entry, true)
	check(layout.town_footprint_colocated, "town fixture missed footprint")
	check(is_equal_approx(layout.sprite_extent_fraction, 1.0), "town visitor still tiny")
	check(layout.sprite_silhouette_model == Style.MODEL, "town visitor contrast route")
	var field: Dictionary = view._hero_draw_layout_payload(rect, entry, false)
	check(field.sprite_rect == layout.sprite_rect, "arrival changes painted size or anchor")
	var other := entry + Vector2i.DOWN
	view._hero_movement_path.assign([entry, other])
	view._hero_movement_active = true
	view._hero_movement_duration_sec = 1.0
	for progress in [0.0, 0.25, 0.5, 0.75, 1.0]:
		view._hero_movement_elapsed_sec = progress
		var state: Dictionary = view._hero_movement_draw_state(view._board_rect())
		check(is_equal_approx(state.sprite_factor, 1.0), "town travel scale pop")
		check(state.hero_rect.size == state.rect.size, "town travel rectangle pop")
	view._hero_movement_active = false
	view._hero_movement_path.clear()
	await capture("town-visitor-inspection-" + scenario)
	check(before == session.to_dict(), "actor presentation changed save/gameplay")
	shell.queue_free()
	await frame()
func run() -> void:
	out = OS.get_environment("BATTLE_READABILITY_OUT")
	var parts := OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	resolution = Vector2i(int(parts[0]), int(parts[1]))
	SettingsService.set_reduced_motion_enabled(true)
	var setup := Select.build_random_map_skirmish_setup_with_retry(
		Select.build_random_map_player_config("medium-random-screenshot-10230", "translated_rmg_template_042_v1", "translated_rmg_profile_042_v1", 4, "land", false, "homm3_medium"),
		"normal", Select.RANDOM_MAP_PLAYER_RETRY_POLICY)
	check(bool(setup.get("ok", false)), "native Medium setup failed")
	if not bool(setup.get("ok", false)): return finish()
	var session = Select.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	var shell = await mount(session)
	session = SessionState.ensure_active_session()
	var view = shell.get_node("%Map")
	var before: Dictionary = session.to_dict().duplicate(true)
	metrics["terrain_hash"] = var_to_str(session.overworld.map).sha256_text()
	metrics["blocked_hash"] = var_to_str(OverworldRules._blocked_tile_index(session)).sha256_text()
	await capture("generated-medium-normal-fog")
	await roster(view)
	check(before == session.to_dict(), "catalog changed generated state/fog")
	check(metrics.blocked_hash == var_to_str(OverworldRules._blocked_tile_index(session)).sha256_text(), "actor drawing changed pathing")
	shell.queue_free()
	await frame()
	for scenario in ["river-pass", "bogbound-oath", "prismhearth-watch", "mireford-skirmish", "orevein-contract", "bellwake-wreck-claim"]:
		await town_fixture(scenario)
	finish()
func finish() -> void:
	MusicAudio.stop_stinger()
	MusicAudio.stop_music("actor_readability_teardown")
	print("BATTLE_READABILITY_REPORT " + JSON.stringify({"ok":failures.is_empty(), "checks":checks, "failures":failures, "metrics":metrics}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


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
