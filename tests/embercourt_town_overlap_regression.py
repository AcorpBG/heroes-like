#!/usr/bin/env python3
"""Embercourt scene composition and unchanged state through the real Town UI."""
import battle_readability_regression as runner
ROOT=runner.ROOT
OUTPUT=ROOT/'.artifacts/embercourt_town_overlap_20260911'
run_probe=runner.run_probe
probe_environment=runner.probe_environment
SCRIPT=r'''extends Node
var checks:=0
var failures:=[]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures.append(message)
func _ready()->void: call_deferred("run")
func run()->void:
	var session=SessionState.set_active_session(ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH))
	OverworldRules.set_active_town_visit(session,"riverwatch_hold")
	session.game_state="town"
	var shell=load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	for i in range(8): await get_tree().process_frame
	var dims:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	var requested:=Vector2i(int(dims[0]),int(dims[1]))
	DisplayServer.window_set_size(requested)
	get_tree().root.size=requested
	get_tree().root.content_scale_size=requested
	var stage=shell.get_node("%TownStage")
	# Negative control restores known pre-fix view geometry only, never content or saves.
	if OS.get_environment("EMBERCOURT_OVERLAP_BASELINE")=="1":
		stage._building_scene_art_manifest=stage._building_scene_art_manifest.duplicate(true)
		var old={"building_bowyer_lodge":[0.49375,0.42,0.1680908203125,0.2],"building_beacon_range":[0.49375,0.421171875,0.16864013671875,0.191796875],"building_quartermasters_depot":[0.2530904134114583,0.440306712962963,0.14784138997395835,0.18006365740740743],"building_embercourt_beacon_court":[0.6986181640625,0.37777777777777777,0.1541162109375,0.18666666666666668]}
		for id in old: stage._building_scene_art_manifest.factions.faction_embercourt[id].normalized_rect=old[id]
	var catalog:Array=ContentService.get_town("town_riverwatch").buildable_building_ids
	catalog=catalog.duplicate()
	for id in ContentService.get_town("town_riverwatch").starting_building_ids:
		if id not in catalog: catalog.append(id)
	var cases={"base":["building_town_hall"],"bowyer":["building_town_hall","building_bowyer_lodge"],"beacon_court":["building_town_hall","building_embercourt_beacon_court"],"quartermaster":["building_town_hall","building_muster_yard","building_quartermasters_depot"],"developed":catalog}
	var rows:=[]
	cases["beacon_range"]=["building_town_hall","building_bowyer_lodge","building_beacon_range"]
	var corrected: Array=["building_stone_store","building_bowyer_lodge","building_beacon_range","building_quartermasters_depot","building_embercourt_beacon_court"]
	for label in cases:
		for town in session.overworld.towns:
			if town.placement_id=="riverwatch_hold": town.built_buildings=cases[label].duplicate()
		shell._refresh()
		for i in range(5): await get_tree().process_frame
		var before:Dictionary=session.to_dict().duplicate(true)
		var entries:Array=stage._town_building_scene_entries(stage._town_scene_rect())
		var visible:=[]
		for entry in entries:
			if entry.visible_building_id!="": visible.append(entry.visible_building_id)
			var id: String=entry.visible_building_id
			if id not in corrected: continue
			var rect: Rect2=entry.normalized_rect
			check(not rect.intersects(Rect2(0.62,0.345,0.155,0.27)),"layer covers protected civic hall: "+id)
			if id=="building_quartermasters_depot":
				check(not rect.intersects(Rect2(0.35,0.49,0.075,0.065)),"depot covers upstream river")
			var summary: Dictionary=stage.validation_building_hotspot_summary(id)
			check(summary.aligned and summary.visible and summary.focus_mode==Control.FOCUS_ALL,"misaligned or inaccessible hotspot: "+id)
			var texture: Texture2D=stage._town_building_texture(id)
			check(absf(rect.size.x*1600.0/(rect.size.y*900.0)-texture.get_width()/float(texture.get_height()))<0.005,"distorted raster: "+id)
			var raster: Image=texture.get_image()
			var ratio: Rect2=entry.texture_region_ratio
			var button: Control=stage._building_hotspots[id]
			var painted_samples:=0
			for y in range(1,10):
				for x in range(1,10):
					var pixel:=Vector2i(Vector2(x/10.0,y/10.0)*Vector2(raster.get_size()))
					var uv:=((Vector2(pixel)+Vector2(0.5,0.5))/Vector2(raster.get_size())-ratio.position)/ratio.size
					if not Rect2(Vector2.ZERO,Vector2.ONE).has_point(uv): continue
					var painted: bool=raster.get_pixelv(pixel).a>0.25
					check(button._has_point(uv*button.size)==painted,"alpha/crop hit region: "+id)
					if painted: painted_samples+=1
			check(painted_samples>0,"building clipped out of viewport: "+id)
			stage._building_hotspots[id].pressed.emit()
			check(shell._town_catalog_is_open(),"building information did not open: "+id)
			var info: Dictionary=shell.validation_building_information_snapshot(id)
			check(info.title==info.expected_title and info.description==info.expected_description,"wrong building information: "+id)
			shell._close_town_catalog(false)
		if label=="beacon_range":
			check("building_beacon_range" in visible and "building_bowyer_lodge" not in visible,"upgrade did not replace base layer")
		check(not visible.is_empty(),"no rendered buildings: "+label)
		var main: Dictionary=shell.validation_activate_main_building_hotspot()
		check(main.same_authoritative_build_route,"main hall ledger routing: "+label)
		shell._close_town_catalog(false)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("BATTLE_READABILITY_OUT").path_join(label+".png"))
		check(session.to_dict()==before,"rendering changed gameplay: "+label)
		rows.append({"case":label,"visible":visible})
	shell.queue_free()
	for i in range(3): await get_tree().process_frame
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"cases":rows}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''
def main():
    runner.OUTPUT=OUTPUT
    runner.SCRIPT=SCRIPT
    runner.run_probe=run_probe
    runner.probe_environment=probe_environment
    return runner.main()
if __name__=='__main__': raise SystemExit(main())
