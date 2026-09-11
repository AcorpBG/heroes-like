#!/usr/bin/env python3
"""All live resource icons/values through the real Overworld shell."""
import battle_readability_regression as runner
ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/overworld_resource_strip_20260911'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
SCRIPT = r'''extends Node
var checks:=0
var failures:=[]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures.append(message)
func _ready()->void: call_deferred("run")
func run()->void:
	var session=SessionState.set_active_session(ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH))
	var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	for i in range(8): await get_tree().process_frame
	var dims:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	var requested:=Vector2i(int(dims[0]),int(dims[1]))
	DisplayServer.window_set_size(requested)
	get_tree().root.size=requested
	get_tree().root.content_scale_size=requested
	for i in range(5): await get_tree().process_frame
	var menu=shell._resource_label
	var viewport:=Rect2(Vector2.ZERO,Vector2(requested))
	check(menu._inline_cells.size()==9,"not all nine live resources have visible cells")
	for scenario in range(3):
		var index:=0
		for id in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
			session.overworld.resources[id]=0 if scenario==0 else (1000+index*13 if scenario==1 else 12345678+index)
			index+=1
		shell._refresh()
		for i in range(5): await get_tree().process_frame
		var before:Dictionary=session.to_dict().duplicate(true)
		var paths:=[]
		var previous:=Rect2()
		for id in OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS:
			var cell:HBoxContainer=menu._inline_cells[id]
			var glyph:TextureRect=cell.get_child(0)
			var amount:Label=cell.get_child(1)
			check(cell.is_visible_in_tree() and viewport.encloses(cell.get_global_rect()),"cell hidden/clipped: "+id)
			check(not previous.intersects(cell.get_global_rect()),"resource cells overlap")
			previous=cell.get_global_rect()
			check(glyph.texture!=null and glyph.texture.resource_path==OverworldRules.resource_icon_path(id),"wrong resource art: "+id)
			paths.append(glyph.texture.resource_path if glyph.texture!=null else "")
			check(amount.text==menu._inline_amount(int(session.overworld.resources[id])),"stale amount: "+id)
			check(str(session.overworld.resources[id]) in cell.tooltip_text,"exact quantity tooltip missing: "+id)
			check(amount.get_theme_font("font").get_string_size(amount.text,HORIZONTAL_ALIGNMENT_LEFT,-1,amount.get_theme_font_size("font_size")).x<=amount.size.x,"amount text clips: "+id)
		check(paths.size()==9 and paths.count(paths[0])==1,"resource art missing or duplicated")
		for path in paths: check(paths.count(path)==1,"shared fallback resource icon: "+path)
		check(viewport.encloses(shell._command_band_panel.get_global_rect()),"footer clips: "+str(shell._command_band_panel.get_global_rect())+" root "+str(shell.size)+" minimum "+str(shell.get_combined_minimum_size()))
		check(not shell._resource_chip_panel.get_global_rect().intersects(shell._map_view.get_global_rect()),"resources cover map")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var capture:=get_viewport().get_texture().get_image()
			check(capture.get_size()==requested,"capture size mismatch")
			capture.save_png(OS.get_environment("BATTLE_READABILITY_OUT").path_join("resources-%d.png"%scenario))
		check(session.to_dict()==before,"resource rendering mutated session")
	shell.present_resource_delta_presentation({"serial":123,"duration_ms":700,"event_id":"ui_resource_delta","cue_id":"cue_ui_resource_delta","action_id":"collect_resource","placement_id":"resource-strip-layout-probe","tile":{"x":1,"y":1},"deltas":[{"resource_id":"wood","delta":13,"before":0,"after":13}],"result_message":"Collected wood","post_action_recap":{},"selected_playback_policy":"queue_resolved","selected_blocking_policy":"nonblocking"})
	for i in range(3): await get_tree().process_frame
	check(shell._resource_delta_cue_row.visible,"resource gain cue did not open")
	check(viewport.encloses(shell._command_band_panel.get_global_rect()),"gain cue clips footer")
	check(not shell._resource_delta_cue_row.get_global_rect().intersects(menu.get_global_rect()),"gain cue covers holdings")
	shell.dismiss_resource_delta_presentation()
	print("RESOURCE_STRIP_POPUP_BEGIN embedded=",get_tree().root.gui_embed_subwindows," native=",menu.get_popup().is_native_menu())
	menu.grab_focus()
	var press:=InputEventAction.new()
	press.action="ui_accept"
	press.pressed=true
	get_viewport().push_input(press)
	for i in range(3): await get_tree().process_frame
	check(menu.get_popup().visible,"resource keyboard popup did not open")
	check(menu.get_popup().item_count==9,"full-value popup lost resources")
	print("RESOURCE_STRIP_POPUP_KEYBOARD_OPEN")
	press=InputEventAction.new()
	press.action="ui_cancel"
	press.pressed=true
	menu._on_popup_window_input(press)
	menu.get_popup().hide()
	for i in range(3): await get_tree().process_frame
	check(menu.has_focus(),"popup close did not return focus")
	print("RESOURCE_STRIP_POPUP_KEYBOARD_CLOSED")
	var rare_cell:Control=menu._inline_cells["memory_salt"]
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.position=rare_cell.get_global_rect().get_center()
	click.global_position=click.position
	click.pressed=true
	get_viewport().push_input(click)
	click=click.duplicate()
	click.pressed=false
	get_viewport().push_input(click)
	for i in range(3): await get_tree().process_frame
	check(menu.get_popup().visible,"clicking a rare-resource icon did not open its full-value popup")
	print("RESOURCE_STRIP_POPUP_POINTER_OPEN")
	menu.get_popup().hide()
	print("RESOURCE_STRIP_POPUP_POINTER_CLOSED")
	shell.queue_free()
	for i in range(3): await get_tree().process_frame
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''
def main():
    runner.OUTPUT=OUTPUT
    runner.SCRIPT=SCRIPT
    runner.run_probe=run_probe
    runner.probe_environment=probe_environment
    return runner.main()
if __name__=='__main__': raise SystemExit(main())
