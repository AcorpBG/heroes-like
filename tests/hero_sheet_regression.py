#!/usr/bin/env python3
"""Owned-hero real input, read-only authority, content and responsive sheet coverage."""
import sys
import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/hero-sheet-20260913'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = ('scenes/overworld/OverworldShell.gdc', 'scenes/shared/HeroSheet.gdc',
                  'scripts/core/HeroCommandRules.gdc', 'scripts/core/ArtifactRules.gdc',
                  'scripts/core/HeroProgressionRules.gdc')
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
func frames()->void:
	for i in range(6): await get_tree().process_frame
func capture(label:String)->void:
	await frames()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("BATTLE_READABILITY_OUT").path_join(label+".png"))
func key(code:int)->void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	get_viewport().push_input(event)
	event=event.duplicate()
	event.pressed=false
	get_viewport().push_input(event)
func inspect_layout(sheet:Control)->void:
	var viewport:=get_viewport().get_visible_rect()
	check(viewport.encloses(sheet._panel.get_global_rect()),"hero panel exceeds viewport: %s %s min=%s" % [sheet.hero.id,sheet._panel.get_global_rect(),sheet._panel.get_combined_minimum_size()])
	for control in sheet.find_children("*","Button",true,false):
		if not control.is_visible_in_tree(): continue
		check(control.focus_mode==Control.FOCUS_ALL,"button not focusable: "+control.name)
		check(control.accessibility_name!="","button missing accessible name: "+control.name)
		if control.has_meta("unit_id") or control==sheet._close:
			check(sheet._panel.get_global_rect().encloses(control.get_global_rect()),"fixed control clipped: "+control.name)
			check(viewport.encloses(control.get_global_rect()),"fixed control offscreen: "+control.name)
func run()->void:
	get_tree().current_scene=null
	var dimensions:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	var requested:=Vector2i(int(dimensions[0]),int(dimensions[1]))
	get_tree().root.size=requested
	get_tree().root.content_scale_size=requested
	var session=SessionState.set_active_session(ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH))
	var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	get_tree().root.add_child(shell)
	get_tree().current_scene=shell
	await frames()
	var hero_id:=String(session.overworld.active_hero_id)
	var button:Button=shell._existing_roster_button(shell._hero_actions,"hero_id",hero_id)
	check(button!=null,"owned roster hero missing")
	shell._roster_scroll.ensure_control_visible(button)
	await frames()
	get_viewport().push_input(pointer(button,false))
	get_viewport().push_input(pointer(button,false,false))
	await frames()
	check(not is_instance_valid(shell._hero_sheet),"single click opened sheet")
	check(button.button_pressed,"single click failed to select hero")
	shell._refresh()
	check(shell._existing_roster_button(shell._hero_actions,"hero_id",hero_id)==button,"refresh discarded target")
	check(button.gui_input.get_connections().filter(func(c):return c.callable.get_method()=="_on_hero_roster_gui_input").size()==1,"duplicate double-click handler")
	for invalid in [pointer(button,true,false),pointer(button,true,true,MOUSE_BUTTON_RIGHT)]:
		shell._on_hero_roster_gui_input(invalid,hero_id)
		check(not is_instance_valid(shell._hero_sheet),"non-left/release opened sheet")
	shell._end_turn_commit_in_progress=true
	check(not shell._open_hero_sheet(hero_id),"end-turn lock bypassed")
	shell._end_turn_commit_in_progress=false
	check(not shell._open_hero_sheet("missing-hero"),"missing/non-owned identity opened")
	var before:Dictionary=session.to_dict().duplicate(true)
	get_viewport().push_input(pointer(button,true))
	get_viewport().push_input(pointer(button,false,false))
	await frames()
	var sheet:Control=shell._hero_sheet
	check(is_instance_valid(sheet) and sheet.visible,"double click did not open hero sheet")
	if not is_instance_valid(sheet):
		print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":false,"checks":checks,"failures":failures}))
		get_tree().quit(1)
		return
	check(sheet.hero.id==hero_id,"wrong hero opened")
	check(sheet.hero.army==session.overworld.army,"active army differs from live state")
	check(sheet.hero.movement==session.overworld.movement,"active movement differs from live state")
	check(sheet.hero.artifacts==ArtifactRules.normalize_hero_artifacts(session.overworld.hero.get("artifacts",{})),"wrong artifact loadout")
	check(sheet.find_child("HeroPortrait",true,false).texture!=null,"portrait missing")
	check(sheet._tabs.get_tab_count()==3,"missing information tab")
	check(sheet.find_children("ArmySlot*","Button",true,false).size()==7,"missing seven-slot army")
	check(shell._overworld_gameplay_movement_blocked_reason()=="hero_sheet_open","map is not blocked")
	check(shell._overworld_order_input_blocked(),"orders remain enabled")
	check(not shell._open_hero_sheet(hero_id),"duplicate sheet opened")
	inspect_layout(sheet)
	var second:Button=sheet.find_child("ArmySlot1",true,false)
	get_viewport().push_input(pointer(second,false))
	get_viewport().push_input(pointer(second,false,false))
	await frames()
	check(String(ContentService.get_unit(String(second.get_meta("unit_id"))).name) in sheet.find_child("UnitDetails",true,false).text,"unit click did not inspect selected stack")
	await capture("army")
	for tab in range(3):
		sheet._tabs.current_tab=tab
		await frames()
		inspect_layout(sheet)
		await capture(["army","artifacts","specializations"][tab])
	key(KEY_RIGHT)
	key(KEY_E)
	await frames()
	check(session.to_dict()==before,"inspection/tab/input changed session")
	key(KEY_ESCAPE)
	await frames()
	check(not sheet.visible,"Escape did not close")
	check(get_viewport().gui_get_focus_owner()==button,"roster focus not restored")
	button.grab_focus()
	key(KEY_ENTER)
	await frames()
	check(sheet.visible,"keyboard roster confirm did not open")
	sheet.close_sheet()
	await frames()
	var controller:=InputEventJoypadButton.new()
	controller.button_index=JOY_BUTTON_A
	controller.pressed=true
	button.grab_focus()
	get_viewport().push_input(controller)
	controller=controller.duplicate()
	controller.pressed=false
	get_viewport().push_input(controller)
	await frames()
	check(sheet.visible,"controller confirm did not open hero sheet")
	for i in range(12):
		key(KEY_TAB)
		await get_tree().process_frame
		check(sheet.is_ancestor_of(get_viewport().gui_get_focus_owner()),"keyboard focus escaped hero modal")
	sheet.close_sheet()
	await frames()
	# A different owned hero must display their own state without activation.
	var other_template:Dictionary={}
	for candidate in ContentService.load_json("res://content/heroes.json").get("items",[]):
		if candidate.id!=hero_id:
			other_template=candidate
			break
	var reserve:Dictionary=HeroCommandRules.build_hero_from_template(other_template,{"x":1,"y":1},{"stacks":[]},session)
	reserve.movement.current=1
	reserve.command.attack=17
	reserve.specialties=["drillmaster","drillmaster","armsmaster","armsmaster"]
	var artifact_items:Array=ContentService.load_json("res://content/artifacts.json").get("items",[])
	reserve.artifacts=ArtifactRules.normalize_hero_artifacts({"inventory":["artifact_warcrest_pennon",artifact_items[1].id]})
	var equipped:Dictionary=ArtifactRules.equip_artifact(reserve,"artifact_warcrest_pennon")
	check(equipped.ok,"equipped artifact fixture failed")
	reserve=equipped.hero
	session.overworld.player_heroes.append(reserve)
	before=session.to_dict().duplicate(true)
	check(shell._open_hero_sheet(String(reserve.id)),"reserve hero cannot be inspected")
	await frames()
	check(sheet.hero.id==reserve.id and sheet.hero.command.attack==17,"reserve stats taken from active hero")
	check(sheet.hero.army.stacks.is_empty(),"empty reserve army replaced with active army")
	check(sheet.hero.artifacts==reserve.artifacts,"reserve artifacts mismatch")
	check(ProgressionRank(sheet.hero)==2,"reserve specialization rank mismatch")
	var bonuses:Dictionary=ArtifactRules.aggregate_bonuses(reserve.duplicate(true))
	var expected_attack:=17+int(bonuses.get("battle_attack",0))+int(HeroProgressionRules.aggregate_bonuses(reserve).get("battle_attack",0))
	check(expected_attack==20,"positive equipment/specialization fixture missing")
	check(sheet.find_child("CommandStats",true,false).get_child(0).text=="Attack\n%d"%expected_attack,"stat omitted equipment/specialization bonus")
	sheet._tabs.current_tab=1
	await frames()
	var artifact_buttons:=sheet.find_children("*","Button",true,false).filter(func(b):return b.has_meta("artifact_id"))
	check(artifact_buttons.size()==2,"equipped/carried artifacts not represented")
	if not artifact_buttons.is_empty(): artifact_buttons[0].pressed.emit()
	await capture("reserve-artifact")
	check(session.to_dict()==before,"reserve inspection mutated authority")
	sheet.close_sheet()
	session.overworld.player_heroes.erase(reserve)
	check(not shell._open_hero_sheet(String(reserve.id)),"stale lost hero opened")
	check(session.overworld.active_hero_id==hero_id,"inspection activated reserve")
	# Active mirrors may be ahead of roster; inspection must not commit them.
	session.overworld.movement.current=0
	before=session.to_dict().duplicate(true)
	var snapshot:Dictionary=HeroCommandRules.hero_inspection_snapshot(session,hero_id)
	check(snapshot.movement.current==0,"snapshot ignored active movement mirror")
	check(session.to_dict()==before,"snapshot committed live state")
	# Every authored identity must resolve its portrait and isolated snapshot.
	var faction_captures:Dictionary={}
	for template in ContentService.load_json("res://content/heroes.json").get("items",[]):
		if template.id==hero_id: continue
		var candidate:Dictionary=HeroCommandRules.build_hero_from_template(template,{"x":2,"y":2},{"stacks":[]},session)
		session.overworld.player_heroes.append(candidate)
		var candidate_before:Dictionary=session.to_dict().duplicate(true)
		var resolved:Dictionary=HeroCommandRules.hero_inspection_snapshot(session,String(candidate.id))
		check(resolved.id==candidate.id and resolved.command==candidate.command,"authored identity snapshot mismatch: "+candidate.id)
		var art:Dictionary=ContentService.get_hero_art(String(candidate.id))
		check(ResourceLoader.exists(String(art.get("portrait","")),"Texture2D"),"authored portrait missing: "+candidate.id)
		var faction:=String(template.get("faction_id",""))
		if not faction_captures.has(faction):
			faction_captures[faction]=true
			check(shell._open_hero_sheet(String(candidate.id)),"faction sheet failed: "+faction)
			await frames()
			inspect_layout(sheet)
			sheet._tabs.current_tab=2
			await capture(faction)
			sheet.close_sheet()
		check(session.to_dict()==candidate_before,"authored snapshot mutated session: "+candidate.id)
		session.overworld.player_heroes.erase(candidate)
	check(Vector2i(get_viewport().get_visible_rect().size)==requested,"actual resolution differs from requested")
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"hero_id":hero_id,"resolution":str(get_viewport().get_visible_rect().size)}))
	get_tree().quit(0 if failures.is_empty() else 1)
func ProgressionRank(hero:Dictionary)->int:
	return HeroProgressionRules.specialty_rank(hero,"drillmaster")
'''

def main():
    if '--platform' in sys.argv:
        import packaged_menu_and_turn_readability_regression as package
        package.ui = sys.modules[__name__]
        return package.main()
    runner.OUTPUT = OUTPUT
    runner.SCRIPT = SCRIPT
    runner.run_probe = run_probe
    runner.probe_environment = probe_environment
    return runner.main()

if __name__ == '__main__':
    raise SystemExit(main())
