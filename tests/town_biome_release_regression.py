#!/usr/bin/env python3
"""Packaged biome resolver + actual generated Overworld to Town input route.

Uses the established SHA-locked Python-owned release probe bootstrap. No loose
game code/art can satisfy a missing pack member. Wine retains every assertion.
"""
import battle_readability_regression as runner
import town_roster_double_click_regression as roster
import packaged_menu_and_turn_readability_regression as package

ROOT = runner.ROOT
OUTPUT = ROOT/'.artifacts/town-biome-fit-20260913/release-entry'
run_probe = runner.run_probe
probe_environment = runner.probe_environment

SETUP = r'''
	var generator = load("res://scripts/core/ScenarioSelectRules.gd")
	var config: Dictionary = generator.build_random_map_player_config("medium-random-screenshot-10230", "translated_rmg_template_042_v1", "translated_rmg_profile_042_v1",4,"land",false,"homm3_medium")
	var setup: Dictionary = generator.build_random_map_skirmish_setup_with_retry(config,"normal",generator.RANDOM_MAP_PLAYER_RETRY_POLICY)
	check(bool(setup.get("ok",false)),"packaged native Medium generation failed")
	if not bool(setup.get("ok",false)):
		print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":false,"checks":checks,"failures":failures}))
		get_tree().quit(1)
		return
	var session = generator.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	session=SessionState.set_active_session(session)
'''
CHECKS = r'''
	var view = shell.get_node("%Map")
	var before: Dictionary = session.to_dict()
	var resolver=load("res://scripts/core/TownBiomeArtRules.gd")
	var skins: Dictionary=ContentService.load_json("res://art/overworld/town_biome_sprites.json")
	var checked := {}
	for base in skins.appearances:
		for terrain in skins.terrain_aliases:
			var row: Dictionary=resolver.resolve(base,terrain,skins)
			var asset: String=row.render_asset_id
			check(asset==String(skins.appearances[base].biome_asset_ids[row.biome_id]),"packaged mapping mismatch "+asset)
			if not checked.has(asset):
				var texture=view._object_texture_for_asset(asset)
				check(texture is Texture2D,"packaged town raster missing "+asset)
				if texture is Texture2D and asset.begins_with("town_biome_"):
					check(texture.get_size()==Vector2(512,512),"packaged biome texture size wrong "+asset)
				var scale: Dictionary=view.validation_town_sprite_scale_payload(asset)
				check(bool(scale.get("town_aspect_preserved",false)) and bool(scale.get("painted_bottom_grounded_exact",false)),"packaged town aspect/grounding changed "+asset)
				checked[asset]=true
	var volcanic_seen:=false
	for town_record in view._towns_by_tile.values():
		var appearance: Dictionary=view._town_biome_appearance(town_record)
		if appearance.render_asset_id=="town_biome_riverwatch_ash": volcanic_seen=true
	check(volcanic_seen,"packaged native Medium did not use volcanic Riverwatch")
	check(session.to_dict()==before,"packaged biome presentation changed authoritative state")
	if DisplayServer.get_name()!="headless":
		var dimensions:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
		get_window().size=Vector2i(int(dimensions[0]),int(dimensions[1]))
		get_window().content_scale_size=get_window().size
		for i in range(5): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("BATTLE_READABILITY_OUT").path_join("native-medium-town.png"))
'''
SCRIPT = roster.SCRIPT.replace(
    '\tvar session=SessionState.set_active_session(ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH))', SETUP)
SCRIPT = SCRIPT.replace('\tvar button:Button=', CHECKS+'\n\tvar button:Button=')


def main():
    runner.OUTPUT=OUTPUT
    runner.SCRIPT=SCRIPT
    runner.run_probe=run_probe
    runner.probe_environment=probe_environment
    return runner.main()


if __name__=='__main__':
    import sys
    package.ui=sys.modules[__name__]
    raise SystemExit(package.main())
