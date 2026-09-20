"""Focused live pickup rendering, GPU shine and collection regression."""
import argparse
from pathlib import Path

from unified_mines_regression import run_probe

SCRIPT = r'''extends Node
const Factory = preload("res://scripts/core/ScenarioFactory.gd")
const Rules = preload("res://scripts/core/OverworldRules.gd")
const View = preload("res://scenes/overworld/OverworldMapView.gd")
const Batch = preload("res://scenes/overworld/OverworldSceneryBatch.gd")
const IDS = ["road_writ_purse", "quarry_chip_hod", "split_wood_pile"]
var failures := []
var checks := 0
var painter = Batch.new()
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message)
func capture() -> Image:
	for i in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()
func clock_at(t: float):
	for entry in painter.entries:
		entry.batch.material.set_shader_parameter("clock_override", t)
		entry.batch.material.set_shader_parameter("phase", 0.0)
func changed(a: Image, b: Image, region: Rect2i) -> int:
	var count := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var d := a.get_pixel(x,y) - b.get_pixel(x,y)
			if maxf(absf(d.r), maxf(absf(d.g),absf(d.b))) > .08: count += 1
	return count
func _ready(): call_deferred("run")
func run():
	var out := OS.get_cmdline_user_args()[0]
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	DisplayServer.window_set_position(Vector2i(-16000,-16000))
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	SettingsService.set_reduced_motion_enabled(false)
	var session = Factory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	Rules.normalize_overworld_state(session)
	session.overworld.resource_nodes=[]
	session.overworld.map_objects=[]
	session.overworld.towns=[]
	session.overworld.encounters=[]
	session.overworld.artifact_nodes=[]
	for i in range(3):
		session.overworld.resource_nodes.append({"site_id":"site_"+IDS[i],"object_id":"object_"+IDS[i],"kind":"reward_reference","placement_id":"shine_%d"%i,"x":3+i,"y":3,"level":0,"collected":false})
	var fog: Dictionary = session.overworld.fog
	for row in fog.explored_tiles: row.fill(true)
	for row in fog.visible_tiles: row.fill(true)
	var view = View.new()
	view.size=Vector2(1280,720)
	add_child(view)
	view.set_map_state(session,session.overworld.map,Vector2i(session.overworld.map[0].size(),session.overworld.map.size()),Vector2i(-1,-1))
	await capture()
	var seen := []
	for entry in view._scenery_batches.entries:
		if entry.get("profile",{}).get("mode",0)==6: seen.append(entry.asset_id)
	check(seen.has("mapobj_"+IDS[0]) and seen.has("mapobj_"+IDS[1]),"live map omits pickup shine")
	check(not seen.has("mapobj_"+IDS[2]),"wood should remain matte")
	var generation: int = view._scenery_batches.generation
	await get_tree().create_timer(.25).timeout
	check(view._scenery_batches.generation==generation,"shine rebuilds map each frame")
	fog.explored_tiles[3][3]=false
	fog.visible_tiles[3][3]=false
	view._invalidate_state_cache("pickup_fog")
	await capture()
	for entry in view._scenery_batches.entries:
		check(entry.get("asset_id","")!="mapobj_"+IDS[0],"hidden gold leaks shine")
	SettingsService.set_reduced_motion_enabled(true)
	check(not view._scenery_motion_enabled(),"reduced-motion preference ignored")
	SettingsService.set_reduced_motion_enabled(false)
	var resources := ["gold","ore","wood"]
	for i in range(3):
		Rules._set_active_hero_position(session,Vector2i(3+i,3),0)
		var claim: Dictionary = Rules.collect_active_resource(session)
		check(bool(claim.get("ok",false)),"cannot collect "+resources[i]+": "+str(claim))
		check(ContentService.get_resource_site("site_"+IDS[i]).rewards[resources[i]]==(1000 if i==0 else 10),"pickup reward changed")
		check(not Rules.resource_node_is_present(session.overworld.resource_nodes[i]),"collected pile remains")
		check(not bool(Rules.collect_active_resource(session).get("ok",false)),"pickup claimed twice")
	view.set_map_state(session,session.overworld.map,Vector2i(session.overworld.map[0].size(),session.overworld.map.size()),Vector2i(-1,-1))
	await capture()
	for entry in view._scenery_batches.entries:
		check(entry.get("profile",{}).get("mode",0)!=6,"collected pickup still shines")
	view.hide()
	var gallery := Control.new()
	add_child(gallery)
	painter.begin(gallery)
	painter.record(&"draw_rect",[Rect2(0,0,1280,720),Color(.14,.17,.10)])
	var samples := []
	for i in range(3):
		var asset: String = "mapobj_"+IDS[i]
		var profile: Dictionary = Batch.profile_for_asset(view._scenery_manifest,asset)
		var texture: Texture2D = view._object_texture_for_asset(asset)
		check(texture!=null,"missing raw pile texture: "+asset)
		painter.record(&"draw_string",[ThemeDB.fallback_font,Vector2(80+i*420,55),resources[i].to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,24])
		for j in range(3):
			var extent: float = [230,42,24][j]
			var center := Vector2(210+i*420,220+j*165)
			var payload: Dictionary = view._object_painted_sprite_draw_payload(asset,texture,center,extent)
			var rect: Rect2 = payload.draw_rect
			if profile.is_empty(): painter.record(&"draw_texture_rect",[payload.draw_texture,rect,false,Color.WHITE])
			else: painter.paint(payload.draw_texture,rect,Color.WHITE,profile,view._object_texture_visible_regions[asset].normalized_source_rect,asset,Vector2i(i,j),0,true)
			samples.append({"resource":resources[i],"extent":extent,"region":Rect2i(rect.grow(3))})
	painter.finish()
	clock_at(0)
	var first := await capture()
	first.save_png(out+"/raw-piles-0.png")
	var peaks := []
	for sample in samples: peaks.append(0)
	for frame in range(1,13):
		clock_at(float(frame)*.25)
		var next := await capture()
		if frame==6: next.save_png(out+"/raw-piles-shine.png")
		for i in range(samples.size()): peaks[i]=maxi(peaks[i],changed(first,next,samples[i].region))
	for i in range(samples.size()):
		var sample: Dictionary = samples[i]
		if sample.resource=="wood": check(peaks[i]==0,"wood has metallic shine")
		else: check(peaks[i]>= (4 if sample.extent==24 else 12),"shine too faint: "+str(sample)+" pixels="+str(peaks[i]))
	check(peaks[1]>peaks[4],"gold sheen not more visible than ore")
	painter.set_motion_enabled(false)
	var still := await capture()
	clock_at(11.0)
	check(still.get_data()==(await capture()).get_data(),"reduced motion changes pixels")
	print("RAW_PICKUP_SHINE_REPORT "+JSON.stringify({"checks":checks,"failures":failures,"visible_pixels":peaks}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(run_probe(SCRIPT, args.godot, args.output, 'RAW_PICKUP_SHINE_REPORT'))
