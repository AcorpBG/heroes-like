#!/usr/bin/env python3
"""Exercise silhouette outlines alongside the authoritative all-town UI probe."""
import all_town_composition_regression as town

ROOT = town.ROOT
OUTPUT = ROOT / '.artifacts/town_building_outlines_20260911'
_run_probe = town.run_probe


def run_probe(command, env, log, timeout_seconds=900):
    # Rendering all masks, screenshot states and 32 animated paid builds needs
    # the same bounded allowance as the packaged all-town runner.
    return _run_probe(command, env, log, timeout_seconds)
probe_environment = town.probe_environment

HELPERS = r'''
func outline_capture(name:String)->void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("BATTLE_READABILITY_OUT")+"/"+name+".png")
func outline_check(button,key:String,shell,stage)->void:
	button._ensure_outline_contours()
	check(not button._outline_contours.is_empty(),"missing alpha contours: "+key)
	check(button._outline_mask==button.painted_mask,"contours do not own current mask: "+key)
	var points:=0
	for contour in button._outline_contours:
		points+=contour.size()
		check(contour[0]==contour[-1],"open silhouette: "+key)
	check(points>5,"rectangle instead of silhouette: "+key)
	for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
		check(button.get_theme_stylebox(state) is StyleBoxEmpty,"rectangular theme decoration: "+key+"/"+state)
	var cached:Array=button._outline_contours.duplicate()
	button._ensure_outline_contours()
	check(button._outline_contours==cached,"steady-state contour drift: "+key)
	var original:Rect2=button.texture_region_ratio
	button.texture_region_ratio=Rect2(.2,.15,.6,.7)
	var uv:Vector2=button._outline_contours[0][0]
	var point:Vector2=button._outline_local_points(button._outline_contours[0])[0]
	check(point.is_equal_approx((uv-Vector2(.2,.15))/Vector2(.6,.7)*button.size),"outline crop projection mismatch: "+key)
	check(button.clip_contents,"cropped silhouette leaks outside its visible region: "+key)
	button.texture_region_ratio=original
	var capture_ids:Dictionary={"faction_embercourt":"building_lantern_archive","faction_mireclaw":"building_gorefen_ring","faction_sunvault":"building_wayfarers_hall","faction_thornwake":"building_thornwake_worldroot_gate","faction_brasshollow":"building_brasshollow_boiler_cathedral","faction_veilmourn":"building_veilmourn_drowned_map_room"}
	var faction:String=key.get_slice("/",0)
	if key.get_slice("/",1)!=capture_ids.get(faction,""):return
	button.release_focus()
	var move:=InputEventMouseMotion.new()
	move.position=Vector2(2,2)
	Input.parse_input_event(move)
	await outline_capture(faction+"-normal")
	var selected:Vector2=exposed_patch(shell,stage,button)
	check(selected.x>=0,"no painted hover point: "+key)
	move=InputEventMouseMotion.new()
	move.position=get_viewport().get_final_transform()*selected
	Input.parse_input_event(move)
	await get_tree().process_frame
	check(button.is_hovered(),"painted point did not hover: "+key)
	await outline_capture(faction+"-hover")
	button.grab_focus()
	await outline_capture(faction+"-focus")
	button.set_pressed_no_signal(true)
	await outline_capture(faction+"-pressed")
	button.set_pressed_no_signal(false)
	button.texture_region_ratio=Rect2(.2,.15,.6,.7)
	button.queue_redraw()
	await outline_capture(faction+"-crop-control")
	button.texture_region_ratio=original
	button.queue_redraw()
	# Finish the real hover before the inherited probe opens/closes dialogs or
	# destroys the town; leave the pointer outside the tested control.
	move=InputEventMouseMotion.new()
	move.position=Vector2(2,2)
	Input.parse_input_event(move)
	await get_tree().process_frame
'''
SCRIPT = town.SCRIPT.replace('func run()->void:', HELPERS + '\nfunc run()->void:').replace(
    '\t\t\tbutton.grab_focus()', '\t\t\tawait outline_check(button,key,shell,stage)\n\t\t\tbutton.grab_focus()')
SCRIPT = SCRIPT.replace('rows.append({"town":template.id,"catalog":catalog.size()})',
                        'rows.append({"town":template.id,"catalog":catalog.size()})\n\t\tprint("OUTLINE_TOWN_CHECKED "+template.id)')
SCRIPT = SCRIPT.replace('for template in templates:\n\t\tvar created=',
                        'for template in templates:\n\t\tprint("OUTLINE_PAID_BUILD "+template.id)\n\t\tvar created=')


def main():
    town.OUTPUT = OUTPUT
    town.SCRIPT = SCRIPT
    town.run_probe = run_probe
    town.probe_environment = probe_environment
    return town.main()


if __name__ == '__main__':
    raise SystemExit(main())
