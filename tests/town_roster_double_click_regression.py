#!/usr/bin/env python3
"""Real pointer input on the town roster, through the normal Town scene route."""
import battle_readability_regression as runner
ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/town_roster_double_click_20260911'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
SCRIPT = r'''extends Node
var checks:=0
var failures:=[]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures.append(message)
func _ready()->void: call_deferred("run")
func pointer(button:Control,double:bool,pressed:bool=true,index:int=MOUSE_BUTTON_LEFT)->InputEventMouseButton:
	var event:=InputEventMouseButton.new()
	event.position=button.get_global_rect().get_center()
	event.global_position=event.position
	event.button_index=index
	event.pressed=pressed
	event.double_click=double
	return event
func run()->void:
	get_tree().current_scene=null
	var session=SessionState.set_active_session(ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH))
	var remote:=OS.get_environment("TOWN_ROSTER_REMOTE")=="1"
	if remote:
		# A second owned holding proves that the previously active town is not
		# reused and that entering management does not march the hero there.
		session.overworld.towns[1].owner="player"
	var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	get_tree().root.add_child(shell)
	get_tree().current_scene=shell
	for i in range(8): await get_tree().process_frame
	var button:Button=shell._town_actions.get_child(1 if remote else 0)
	shell._roster_scroll.ensure_control_visible(button)
	for i in range(5): await get_tree().process_frame
	var id:=String(button.get_meta("town_placement_id"))
	if remote:
		OverworldRules.set_active_town_visit(session,String(session.overworld.towns[0].placement_id))
		check(String(session.flags.get("active_town_placement_id",""))!=id,"remote fixture did not start with a different active town")
	var town:Dictionary={}
	for value in session.overworld.towns:
		if value.placement_id==id: town=value
	check(not town.is_empty(),"no owned town fixture")
	var hero_before=OverworldRules.hero_position(session)
	var movement_before:Dictionary=session.overworld.movement.duplicate(true)
	var resources_before:Dictionary=session.overworld.resources.duplicate(true)
	get_viewport().push_input(pointer(button,false))
	get_viewport().push_input(pointer(button,false,false))
	for i in range(3): await get_tree().process_frame
	check(session.game_state=="overworld","single click entered town")
	check(String(shell._town_at(shell._selected_tile.x,shell._selected_tile.y).get("placement_id",""))==id,"single click selected wrong town")
	check(button.button_pressed,"single click did not select roster card")
	shell._refresh()
	check(shell._existing_roster_button(shell._town_actions,"town_placement_id",id)==button,"refresh discarded double-click target")
	check(button.gui_input.get_connections().filter(func(c):return c.callable.get_method()=="_on_town_roster_gui_input").size()==1,"refresh duplicated input handler")
	for invalid in [pointer(button,true,false),pointer(button,true,true,MOUSE_BUTTON_RIGHT)]:
		shell._on_town_roster_gui_input(invalid,id)
		check(session.game_state=="overworld","non-left/release entered town")
	shell._end_turn_commit_in_progress=true
	shell._on_town_roster_gui_input(pointer(button,true),id)
	check(session.game_state=="overworld","double click bypassed end-turn lock")
	shell._end_turn_commit_in_progress=false
	shell._on_town_roster_gui_input(pointer(button,true),"missing-town")
	check(session.game_state=="overworld","missing roster identity entered town")
	for value in session.overworld.towns:
		if value.placement_id==id: value.owner="enemy"
	shell._on_town_roster_gui_input(pointer(button,true),id)
	check(session.game_state=="overworld","stale lost town entered management")
	for value in session.overworld.towns:
		if value.placement_id==id: value.owner="player"
	check("double-click" in button.tooltip_text,"double-click affordance absent")
	get_viewport().push_input(pointer(button,true))
	for i in range(60):
		await get_tree().process_frame
		if get_tree().current_scene!=null and get_tree().current_scene.scene_file_path=="res://scenes/town/TownShell.tscn": break
	check(session.game_state=="town","double click did not set Town state")
	check(get_tree().current_scene!=null and get_tree().current_scene.scene_file_path=="res://scenes/town/TownShell.tscn","double click did not open actual Town window")
	check(String(session.flags.get("active_town_placement_id",""))==id,"wrong town placement opened")
	check(OverworldRules.hero_position(session)==hero_before,"town entry moved hero")
	if remote: check(OverworldRules.hero_position(session)!=Vector2i(int(town.x),int(town.y)),"remote fixture was at the hero")
	check(session.overworld.movement==movement_before,"town entry spent movement")
	check(session.overworld.resources==resources_before,"town entry changed resources")
	if DisplayServer.get_name()!="headless":
		for i in range(5): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("BATTLE_READABILITY_OUT").path_join("opened-town.png"))
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"placement_id":id}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''
def main():
    runner.OUTPUT=OUTPUT
    runner.SCRIPT=SCRIPT
    runner.run_probe=run_probe
    runner.probe_environment=probe_environment
    return runner.main()
if __name__=='__main__': raise SystemExit(main())
