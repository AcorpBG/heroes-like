"""Render a faction's four hall stages and exercise their actual input route."""
import argparse
from pathlib import Path
from town_development_regression import SCRIPT as FIXTURE
from unified_mines_regression import run_probe

SCRIPT = FIXTURE.split('func run():')[0] + r'''
func run():
	var ids=["building_town_hall","building_dev_hall_2","building_dev_hall_3","building_dev_hall_4"]
	var s=fixture("town_riverwatch")
	s=SessionState.set_active_session(s);s.game_state="town"
	var shell=load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	var seen=[]
	for stage in range(4):
		if stage>0: build(s,ids[stage])
		shell._refresh()
		for frame in range(10):await get_tree().process_frame
		var view=shell._town_stage_view
		check(view._resolved_scenic_backdrop_path.contains("/overhaul/"),"old baked-building backdrop selected")
		var entries:Array=view._town_building_scene_entries(view._town_scene_rect())
		var halls=entries.filter(func(e):return e.plot_id=="hall")
		check(halls.size()==1,"one hall plot")
		check(halls[0].visible_building_id==ids[stage],"active hall stage")
		check(not halls[0].embedded_in_base,"hall hidden in backdrop")
		var path:String=view._town_building_texture_path(ids[stage])
		check(path not in seen,"hall stage reuses painting")
		seen.append(path)
		check(view._town_building_texture(ids[stage])!=null,"painting imported")
		check(Towns.building_icon_path(ids[stage],"faction_embercourt").contains("/overhaul/"),"faction icon missing")
		check(Towns.building_icon_path(ids[stage],"faction_mireclaw")!=Towns.building_icon_path(ids[stage],"faction_embercourt"),"hall icon leaked to other faction")
		check(not view.main_building_hotspot_control().visible,"obsolete baked hall hotspot visible")
		var hotspot:Dictionary=view.validation_building_hotspot_summary(ids[stage])
		check(hotspot.visible and hotspot.aligned,"hall input bounds")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]+"/hall-%d.png"%(stage+1))
		view.validation_activate_building_hotspot(ids[stage])
		for frame in range(3):await get_tree().process_frame
		check(shell._town_catalog_mode=="build" and shell._town_catalog_is_open(),"hall does not open construction")
		shell._close_town_catalog(false)
	# Review the largest hall with the rest of the live town built around it.
	var town:Dictionary=s.overworld.towns[0]
	town.built_buildings=ContentService.get_town(town.town_id).buildable_building_ids.duplicate()
	Dev.migrate_town(town)
	shell._refresh()
	for frame in range(8):await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0]+"/developed.png")
	print("TOWN_HALL_ART_REPORT "+JSON.stringify({"checks":checks,"failures":failures}))
	shell.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
'''

def script_for_faction(faction):
    if faction == 'sunvault':
        return (SCRIPT.replace('faction_embercourt', 'faction_sunvault')
                .replace('town_riverwatch', 'town_prismhearth'))
    if faction == 'mireclaw':
        # Substitute together so the comparison still targets the other faction.
        return (SCRIPT.replace('faction_mireclaw', 'other_faction')
                .replace('faction_embercourt', 'faction_mireclaw')
                .replace('other_faction', 'faction_embercourt')
                .replace('town_riverwatch', 'town_duskfen'))
    return SCRIPT


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--faction', choices=['embercourt', 'mireclaw', 'sunvault'], default='embercourt')
    args=parser.parse_args()
    raise SystemExit(run_probe(script_for_faction(args.faction),args.godot,args.output,'TOWN_HALL_ART_REPORT'))
