"""Bounded chest choice, save continuity, dialog and GPU animation regression."""
import argparse
from pathlib import Path

from unified_mines_regression import run_probe

SCRIPT = r'''extends Node
const Factory = preload("res://scripts/core/ScenarioFactory.gd")
const Rules = preload("res://scripts/core/OverworldRules.gd")
const Store = preload("res://scripts/core/SessionStateStore.gd")
const View = preload("res://scenes/overworld/OverworldMapView.gd")
const Batch = preload("res://scenes/overworld/OverworldSceneryBatch.gd")
var checks := 0
var failures := []
var painter = Batch.new()
func check(ok: bool, message: String):
	checks += 1
	if not ok: failures.append(message)
func fixture(difficulty: String = "normal"):
	var session = Factory.create_session("river-pass", difficulty, SessionState.LAUNCH_MODE_SKIRMISH)
	Rules.normalize_overworld_state(session)
	session.overworld.towns=[]
	session.overworld.encounters=[]
	session.overworld.map_objects=[]
	session.overworld.artifact_nodes=[]
	session.overworld.resource_nodes=[{"site_id":"site_waystone_cache","object_id":"object_waystone_cache","kind":"reward_reference","placement_id":"choice_chest","x":3,"y":3,"level":0,"collected":false}]
	for row in session.overworld.map: row.fill("grass")
	for row in session.overworld.fog.explored_tiles: row.fill(true)
	for row in session.overworld.fog.visible_tiles: row.fill(true)
	Rules._set_active_hero_position(session,Vector2i(3,3),0)
	Rules.invalidate_spatial_lookup(session)
	return session
func clock_at(value: float):
	for entry in painter.entries:
		entry.batch.material.set_shader_parameter("clock_override",value)
		entry.batch.material.set_shader_parameter("phase",0.0)
func capture() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()
func changed(a: Image, b: Image, region: Rect2i) -> int:
	var n:=0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var d:=a.get_pixel(x,y)-b.get_pixel(x,y)
			if maxf(absf(d.r),maxf(absf(d.g),absf(d.b)))>.055: n+=1
	return n
func _ready(): call_deferred("run")
func run():
	var out:=OS.get_cmdline_user_args()[0]
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	DisplayServer.window_set_position(Vector2i(-16000,-16000))
	get_tree().root.size=Vector2i(1280,720)
	get_tree().root.content_scale_size=Vector2i(1280,720)
	SettingsService.set_reduced_motion_enabled(false)
	for difficulty in ["normal","hard","story"]:
		for choice in ["gold","experience"]:
			var session=fixture(difficulty)
			var gold:=int(session.overworld.resources.gold)
			var xp:=int(session.overworld.hero.experience)
			var opened:Dictionary=Rules.collect_active_resource(session)
			check(opened.get("route","")=="reward_choice","visit did not request a choice")
			check(session.overworld.resources.gold==gold and session.overworld.hero.experience==xp and not session.overworld.resource_nodes[0].collected,"opening granted loot")
			var context:Dictionary=opened.reward_choice.context
			check(not Rules.choose_resource_reward(session,"both",context).ok,"invalid choice accepted")
			var picked:Dictionary=Rules.choose_resource_reward(session,choice,context)
			check(picked.ok,"cannot choose "+choice+": "+str(picked))
			check(session.overworld.resources.gold-gold==(2000 if choice=="gold" else 0),"wrong gold or both rewards granted")
			check(session.overworld.hero.experience-xp==(1000 if choice=="experience" else 0),"wrong hero experience")
			check(not Rules.resource_node_is_present(session.overworld.resource_nodes[0]),"chosen chest remains")
			var restored=Store.SessionData.new()
			restored.from_dict(session.to_dict())
			Rules.normalize_overworld_state(restored)
			check(restored.overworld.resource_nodes[0].get("reward_choice_id","")==choice,"choice lost through save normalization")
			check(not Rules.choose_resource_reward(restored,choice,context).ok,"restored chest claimed twice")
	var session=fixture()
	var opened:Dictionary=Rules.collect_active_resource(session)
	var context:Dictionary=opened.reward_choice.context
	var stale:=context.duplicate(true)
	stale.hero_id="different_hero"
	check(not Rules.choose_resource_reward(session,"gold",stale).ok,"wrong hero choice accepted")
	Rules._set_active_hero_position(session,Vector2i(7,7),0)
	check(not Rules.choose_resource_reward(session,"gold",context).ok,"distant stale choice accepted")
	var unclaimed=Store.SessionData.new()
	unclaimed.from_dict(session.to_dict())
	Rules._set_active_hero_position(unclaimed,Vector2i(3,3),0)
	check(Rules.collect_active_resource(unclaimed).get("route","")=="reward_choice","unselected chest not resumable")
	session=fixture()
	Rules._set_active_hero_position(session,Vector2i(2,3),0)
	var moved:Dictionary=Rules.try_move(session,1,0)
	check(moved.has("reward_choice") and not session.overworld.resource_nodes[0].collected,"movement loses choice payload or auto-collects")
	session=fixture()
	# The alternate native cache object ID still uses this live reward site.
	session.overworld.resource_nodes[0].object_id="object_moss_oath_cache"
	check(Rules.collect_active_resource(session).get("route","")=="reward_choice","native cache alias lost choice")
	var view=View.new()
	view.size=Vector2(1280,720)
	add_child(view)
	view.set_map_state(session,session.overworld.map,Vector2i(session.overworld.map[0].size(),session.overworld.map.size()),Vector2i(-1,-1))
	await capture()
	var animated:=false
	for entry in view._scenery_batches.entries:
		if entry.get("asset_id","")=="mapobj_waystone_cache": animated=entry.get("profile",{}).get("mode",0)==7
	check(animated,"live map does not animate chest")
	var generation:int=view._scenery_batches.generation
	await get_tree().create_timer(.2).timeout
	check(view._scenery_batches.generation==generation,"animation rebuilds map")
	session.overworld.fog.explored_tiles[3][3]=false
	session.overworld.fog.visible_tiles[3][3]=false
	view._invalidate_state_cache("chest_fog")
	await capture()
	for entry in view._scenery_batches.entries:
		check(entry.get("asset_id","")!="mapobj_waystone_cache","chest glows through fog")
	view.hide()
	var gallery:=Control.new()
	add_child(gallery)
	var profile:Dictionary=Batch.profile_for_asset(view._scenery_manifest,"mapobj_waystone_cache")
	var texture:Texture2D=view._object_texture_for_asset("mapobj_waystone_cache")
	check(texture!=null,"chest texture unavailable")
	painter.begin(gallery)
	painter.record(&"draw_rect",[Rect2(0,0,1280,720),Color(.13,.18,.11)])
	var regions:=[]
	for i in range(3):
		var extent:float=[320,64,40][i]
		var payload:Dictionary=view._object_painted_sprite_draw_payload("mapobj_waystone_cache",texture,Vector2(230+i*400,380),extent)
		var rect:Rect2=payload.draw_rect
		painter.paint(payload.draw_texture,rect,Color.WHITE,profile,view._object_texture_visible_regions["mapobj_waystone_cache"].normalized_source_rect,"mapobj_waystone_cache",Vector2i(i,0),0,true)
		regions.append(Rect2i(rect.grow(2)))
	painter.finish()
	clock_at(0)
	var first:=await capture()
	first.save_png(out+"/chest-effects-0.png")
	var peaks:=[0,0,0]
	for frame in range(1,10):
		clock_at(frame*.3)
		var next:=await capture()
		if frame==3:next.save_png(out+"/chest-effects-1.png")
		for i in range(3):peaks[i]=maxi(peaks[i],changed(first,next,regions[i]))
	for i in range(3):check(peaks[i]>=(5 if i==2 else 12),"animation unreadable at size "+str(i)+": "+str(peaks))
	painter.set_motion_enabled(false)
	var still:=await capture()
	clock_at(17)
	check(still.get_data()==(await capture()).get_data(),"reduced motion still animates")
	gallery.hide()
	SessionState.active_session=fixture()
	var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	shell._on_context_action_pressed("collect_resource")
	await get_tree().process_frame
	check(is_instance_valid(shell._resource_reward_dialog) and shell._resource_reward_dialog.visible,"live interaction does not open reward dialog")
	(await capture()).save_png(out+"/chest-choice-dialog.png")
	shell._on_resource_reward_canceled()
	check(not SessionState.active_session.overworld.resource_nodes[0].collected,"cancel collects chest")
	shell._on_context_action_pressed("collect_resource")
	await get_tree().process_frame
	var xp_before:int=SessionState.active_session.overworld.hero.experience
	shell._on_resource_reward_selected("experience")
	check(SessionState.active_session.overworld.hero.experience==xp_before+1000,"dialog selection did not grant experience")
	print("WAYSTONE_CHEST_REPORT "+JSON.stringify({"checks":checks,"failures":failures,"animation_changed_pixels":peaks}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(run_probe(SCRIPT, args.godot, args.output, 'WAYSTONE_CHEST_REPORT'))
