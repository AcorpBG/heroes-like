"""Focused rare-mine aliases, geometry, flags, income and GPU animation check."""
import argparse
from pathlib import Path
from unified_mines_regression import run_probe

SCRIPT = r'''extends Node
const Factory = preload("res://scripts/core/ScenarioFactory.gd")
const Rules = preload("res://scripts/core/OverworldRules.gd")
const Mines = preload("res://scripts/core/MineRules.gd")
const Art = preload("res://scenes/overworld/OverworldMine.gd")
const View = preload("res://scenes/overworld/OverworldMapView.gd")
const Batch = preload("res://scenes/overworld/OverworldSceneryBatch.gd")
const Flag = preload("res://scenes/overworld/OverworldControlFlag.gd")
const Players = preload("res://scripts/core/PlayerIdentityRules.gd")
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
		entry.batch.material.set_shader_parameter("clock_override",t)
		entry.batch.material.set_shader_parameter("phase",0.0)
func changed(a: Image, b: Image, region: Rect2i, threshold: float) -> int:
	var count := 0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var delta := a.get_pixel(x,y)-b.get_pixel(x,y)
			if maxf(absf(delta.r),maxf(absf(delta.g),absf(delta.b)))>=threshold: count+=1
	return count
func _ready(): call_deferred("run")
func run():
	var out: String = OS.get_cmdline_user_args()[0]
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution("1280x720")
	SettingsService.set_reduced_motion_enabled(false)
	DisplayServer.window_set_position(Vector2i(-16000,-16000))
	get_tree().root.size=Vector2i(1280,720)
	get_tree().root.content_scale_size=Vector2i(1280,720)
	var session = Factory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	Rules.normalize_overworld_state(session)
	var rows:=[]; var explored:=[]
	for y in range(12):
		var row:=[]; var known:=[]
		for x in range(18): row.append("grass"); known.append(true)
		rows.append(row); explored.append(known)
	session.overworld.map=rows
	session.overworld.map_size={"width":18,"height":12,"level_count":1}
	session.overworld.fog={"explored_tiles":explored,"visible_tiles":explored.duplicate(true)}
	session.overworld.artifact_nodes=[]
	var view = View.new(); view.size=Vector2(1280,720); add_child(view)
	var aliases := []; var identities := {}
	for site in ContentService.load_json("res://content/resource_sites.json").items:
		if not site.has("rare_mine_resource"): continue
		aliases.append(site); identities[site.rare_mine_resource]=true
		var resource: String=site.rare_mine_resource
		var node := {"site_id":site.id,"kind":"mine","object_id":"object_cinder_ore_face","x":4,"y":4,"visit_tile":{"x":5,"y":5},"placement_id":site.id,"level":0,"runtime_footprint":{"width":1,"height":1},"package_block_tiles":[{"x":9,"y":9}],"collected":false}
		check(view._resource_asset_id(node)=="mapobj_rare_%s_mine"%resource,"wrong shared art: "+site.id)
		check(view._object_profile_footprint(view._resource_object_profile(node))==Vector2i(3,2),"wrong footprint: "+site.id)
		check(Mines.body_tiles(node).size()==6 and Mines.block_tiles(node).size()==5,"wrong occupancy: "+site.id)
		session.overworld.resource_nodes=[node]; session.overworld.towns=[]; session.overworld.map_objects=[]; session.overworld.encounters=[]
		var original: Dictionary=node.duplicate(true)
		var blocked: Dictionary=Rules._build_blocked_tile_index(session,0)
		for point in Mines.block_tiles(node): check(blocked.has("%d,%d"%[point.x,point.y]),"missing body cell: "+site.id)
		check(not blocked.has("5,5") and not blocked.has("9,9"),"visit blocked or old mask retained: "+site.id)
		check(Rules._resource_node_world_interaction_tiles({},node)==[Vector2i(5,5)],"entry moved: "+site.id)
		check(node==original,"source record mutated: "+site.id)
		check(view._mine_control_flag_profile(node,Rect2(0,0,58,58)).color==Flag.NEUTRAL,"neutral flag missing: "+site.id)
		node.collected_by_player_id="rare_test_player"
		for day in [2,8]:
			var income: Dictionary=Rules.controlled_resource_site_income(session,"rare_test_player",day)
			check(income[resource]==1 and income.gold==0,"rare mine must produce only its rare resource: "+site.id)
		var claim: Dictionary=Rules._resource_site_claim_rewards(site)
		check(claim.get(resource,0)==1 and claim.get("gold",0)==0,"rare mine capture must not award gold: "+site.id)
		check(Rules.controlled_resource_site_income(session,"other_player",2)[resource]==0,"income wrong owner: "+site.id)
		check(Mines.resource({"site_id":site.id,"kind":"reward_reference"}).is_empty(),"pickup became building: "+site.id)
	check(aliases.size()==9 and identities.size()==6,"expected nine aliases / six identities")
	for pair in [["aetherglass","site_aetherglass_lens_house"],["embergrain","site_embergrain_warm_granary"],["peatwax","site_peatwax_reed_yard"],["memory_salt","site_memory_salt_pan"]]:
		check(view._resource_asset_id({"site_id":pair[1],"object_id":"object_cinder_ore_face","kind":"reward_reference"})=="resource_pickup_"+pair[0],"loose resource uses mine art")
	for site in ["site_frontier_rare_exchange","site_orevein_assay_depot","site_bellwake_wreck_ledger","site_generated_town_required_source_cache"]:
		check(Mines.resource({"site_id":site}).is_empty(),"mixed producer became mine: "+site)
	# Actual cached map rendering, fog and owner changes for all six resource types.
	var nodes := []; var seen := {}
	for site in aliases:
		if seen.has(site.rare_mine_resource): continue
		seen[site.rare_mine_resource]=true
		var i:=nodes.size()
		nodes.append({"site_id":site.id,"placement_id":site.id,"x":3+(i%3)*4,"y":4+(i/3)*5,"level":0,"collected":false})
	session.overworld.resource_nodes=nodes
	var fog: Dictionary=session.overworld.fog
	for row in fog.explored_tiles: row.fill(true)
	for row in fog.visible_tiles: row.fill(true)
	var map_size:=Vector2i(session.overworld.map[0].size(),session.overworld.map.size())
	view.set_map_state(session,session.overworld.map,map_size,Vector2i(-1,-1))
	var saved: Dictionary=session.to_dict().duplicate(true)
	var live:=await capture(); live.save_png(out+"/rare-live.png")
	var drawn := {}; var cells := []
	for entry in view._scenery_batches.entries:
		if entry.get("kind","")=="rare_mine": drawn[entry.resource]=true; cells.append(entry.cell)
	check(drawn.size()==6,"not all rare mines use animated map renderer")
	var flag_poles:={}
	for entry in view._scenery_batches.entries:
		if entry.get("kind","")=="mine_control_flag":
			flag_poles[entry.pole_base]=true
			check(entry.color==Flag.NEUTRAL,"unclaimed rare flag not grey")
	check(flag_poles.size()==6,"not all dedicated rare mines have control flags")
	var generation:int=view._scenery_batches.generation
	await get_tree().create_timer(.2).timeout
	check(view._scenery_batches.generation==generation,"animation rebuilt cached map")
	if not cells.is_empty():
		var hidden:Vector2i=cells[0]; fog.explored_tiles[hidden.y][hidden.x]=false; fog.visible_tiles[hidden.y][hidden.x]=false
		view._invalidate_state_cache("rare_mine_fog"); await capture()
		for entry in view._scenery_batches.entries:
			if entry.get("kind","")=="rare_mine": check(entry.cell!=hidden,"mine leaked into unexplored fog")
	session.overworld.fog=saved.overworld.fog.duplicate(true)
	check(session.to_dict()==saved,"render changed save state")
	view.hide()
	var gallery:=Control.new(); add_child(gallery)
	var art:=Art.new(); art.configure(ContentService.load_json("res://art/overworld/common_mines.json"),ContentService.load_json("res://art/overworld/rare_mines.json"))
	check(art.manifest.mines.size()==9,"common/rare manifest merge lost a resource")
	var resources: Array=identities.keys(); var samples:=[]
	var ground_config:=ContentService.load_json("res://art/overworld/ground_materials.json")
	var ground:Texture2D=load(ground_config.atlas)
	painter.begin(gallery)
	for i in range(6):
		var origin:=Vector2((i%3)*426,(i/3)*360)
		var terrain:String=["grass","sand","snow"][i%3]
		var slot:=int(ground_config.terrain_slots[terrain]); var source:=Rect2(Vector2(slot%4,slot/4)*512,Vector2(512,512))
		painter.record(&"draw_texture_rect_region",[ground,Rect2(origin,Vector2(426,360)),source])
		painter.record(&"draw_string",[ThemeDB.fallback_font,origin+Vector2(12,25),String(resources[i]).to_upper().replace("_"," "),HORIZONTAL_ALIGNMENT_LEFT,-1,17])
		for j in range(2):
			var width:=174.0 if j==0 else 108.0
			var foot:=Rect2(origin+Vector2(30 if j==0 else 280,315-width*2/3),Vector2(width,width*2/3))
			var pose:Dictionary=art.payload(resources[i],foot)
			painter.paint_material(pose.texture,pose.rect,Color.WHITE,Art.material(pose,resources[i],true),{})
			samples.append(pose)
	painter.finish(); clock_at(0); var first:=await capture(); first.save_png(out+"/rare-0.png")
	clock_at(.85); var second:=await capture(); second.save_png(out+"/rare-1.png")
	for entry in painter.entries: entry.batch.material.set_shader_parameter("chimney",Vector2(-10,-10))
	var no_smoke:=await capture()
	for i in range(samples.size()):
		var pose:Dictionary=samples[i]; var scale:Vector2=pose.rect.size/pose.canvas
		var chimney:=Vector2(pose.entry.chimney[0],pose.entry.chimney[1])
		painter.entries[i].batch.material.set_shader_parameter("chimney",chimney/pose.canvas)
		var smoke:=Rect2i(pose.rect.position+(chimney-Vector2(25,125))*scale,Vector2(90,118)*scale)
		check(changed(second,no_smoke,smoke,.08)>=maxi(12,int(400*scale.x*scale.y)),"faint smoke: "+pose.resource)
		for part in pose.entry.parts:
			var region:=Rect2i(pose.rect.position+Vector2(part.rect[0],part.rect[1])*scale,Vector2(part.rect[2],part.rect[3])*scale)
			check(changed(first,second,region,.03)>3,"static machinery: "+pose.resource)
		for light in pose.entry.lights:
			var region:=Rect2i(pose.rect.position+(Vector2(light[0],light[1])-Vector2(22,22))*scale,Vector2(44,44)*scale)
			check(changed(first,second,region,.045)>=maxi(4,int(55*scale.x*scale.y)),"faint lamp: "+pose.resource)
	painter.set_motion_enabled(false); var still:=await capture(); clock_at(4.7); var later:=await capture()
	check(still.get_data()==later.get_data(),"reduced motion still animates")
	print("RARE_MINES_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(run_probe(SCRIPT, args.godot, args.output, 'RARE_MINES_REPORT'))
