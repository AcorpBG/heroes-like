"""Focused Embercourt building rendering and developed-town painted input."""
import argparse
from pathlib import Path
from town_development_regression import SCRIPT as FIXTURE
from unified_mines_regression import run_probe

SCRIPT = FIXTURE.split('func run():')[0] + r'''
func capture(name:String):
	for frame in range(8):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]+"/"+name+".png")
func check_exposed(view):
	var controls:Array=view.building_hotspot_controls()
	var counts={}
	for button in controls:
		var exposed:=0
		var painted:=0
		for y in range(20):
			for x in range(20):
				var p:Vector2=button.size*Vector2((x+.5)/20.,(y+.5)/20.)
				if not button._has_point(p):continue
				painted+=1
				var screen:Vector2=button.position+p
				var covered:=false
				for other in controls:
					if other.get_index()>button.get_index() and other._has_point(screen-other.position):
						covered=true;break
				if not covered:exposed+=1
		counts[button.name]=[exposed,painted]
		check(exposed>=8,"no usable painted input: "+button.name)
	print("EXPOSED_BUILDINGS "+JSON.stringify(counts))
func run():
	var s=fixture("town_riverwatch")
	s=SessionState.set_active_session(s);s.game_state="town"
	for id in ["building_dev_hall_2","building_dev_hall_3","building_dev_hall_4"]:build(s,id)
	var shell=load("res://scenes/town/TownShell.tscn").instantiate();add_child(shell)
	var lines={
		"fort":["building_dev_fort_1","building_dev_fort_2","building_dev_fort_3"],
		"market":["building_market_square","building_dev_trade_exchange"],
		"storehouse":["building_dev_storehouse_1","building_dev_storehouse_2"],
		"guild":["building_dev_guild_1","building_dev_guild_2","building_dev_guild_3","building_dev_guild_4","building_dev_guild_5"],
		"building_wayfarers_hall":["building_wayfarers_hall"],
		"building_dev_growth_1":["building_dev_growth_1"],
		"building_dev_growth_2":["building_dev_growth_2"],
		"building_dev_growth_3":["building_dev_growth_3"],
		"building_dev_training_attack":["building_dev_training_attack"],
		"building_dev_training_defense":["building_dev_training_defense"],
		"building_dev_training_experience":["building_dev_training_experience"],
		"building_dev_artifact_exchange":["building_dev_artifact_exchange"],
		"building_dev_embercourt_unique_1":["building_dev_embercourt_unique_1"],
		"building_dev_embercourt_unique_2":["building_dev_embercourt_unique_2"],
		"building_dev_embercourt_unique_3":["building_dev_embercourt_unique_3"]}
	var seen=[]
	for plot in lines:
		for id in lines[plot]:
			build(s,id);shell._refresh()
			await capture(id)
			var view=shell._town_stage_view
			var active:Array=view._town_building_scene_entries(view._town_scene_rect()).filter(func(e):return e.plot_id==plot)
			check(active.size()==1 and active[0].visible_building_id==id,"stage not replaced: "+id)
			var path:String=view._town_building_texture_path(id)
			check(path.contains("/overhaul/") and path not in seen,"old or reused painting: "+id);seen.append(path)
			check(view._town_building_texture(id)!=null,"missing texture: "+id)
			check(Towns.building_icon_path(id,"faction_embercourt").contains("/overhaul/"),"wrong icon: "+id)
			check(view.validation_building_hotspot_summary(id).aligned,"misaligned input: "+id)
			view.validation_activate_building_hotspot(id)
			for frame in range(2):await get_tree().process_frame
			check(shell._town_catalog_is_open(),"information route: "+id)
			shell._close_town_catalog(false)
	for branch in [1,2]:
		var town:Dictionary=s.overworld.towns[0]
		town.built_buildings=[]
		for id in ContentService.get_town(town.town_id).buildable_building_ids:
			var b=ContentService.get_building(id)
			if b.get("choice_group","")=="" or int(b.get("choice_branch",0))==branch:town.built_buildings.append(id)
		Dev.migrate_town(town);shell._refresh()
		await capture("developed-branch-%d"%branch)
		check_exposed(shell._town_stage_view)
	print("TOWN_CIVIC_ART_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	shell.queue_free();await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
'''

if __name__ == '__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--godot',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    raise SystemExit(run_probe(SCRIPT,args.godot,args.output,'TOWN_CIVIC_ART_REPORT'))
