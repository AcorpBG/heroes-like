#!/usr/bin/env python3
"""All authored Town layers: aspect, exposed input, information, and view purity.

Development fixtures are presentation controls, not earned progression evidence.
Paid construction/save controls use isolated prerequisite/resource fixtures.
"""
import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/all_town_repair_20260911'
_run_probe = runner.run_probe
def run_probe(command, env, log, timeout_seconds=300):
    # All-town pointer events plus 32 animated builds exceed the shared runner's
    # 1800-frame cap. Retain its wall-clock timeout instead of truncating checks.
    command = list(command)
    if '--quit-after' in command:
        index = command.index('--quit-after')
        del command[index:index + 2]
    return _run_probe(command, env, log, timeout_seconds)
probe_environment = runner.probe_environment
SCRIPT = r'''extends Node
var checks:=0
var failures:=[]
var rows:=[]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: failures.append(message)
func _ready()->void: call_deferred("run")
func click(point:Vector2)->void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=get_viewport().get_final_transform()*point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
func normalized(value:Variant)->Variant:
	return JSON.parse_string(JSON.stringify(value))
func expected_build(session,id:String,action:Dictionary)->Dictionary:
	var control=SessionStateStore.SessionData.new()
	control.from_dict(session.to_dict())
	var cache:Dictionary=OverworldRules._runtime_normalized_signatures.duplicate(true)
	OverworldRules.begin_normalized_read_scope(control)
	TownRules.begin_read_scope(control)
	var before:Dictionary=TownRules.town_action_consequence_signature(control)
	TownRules.end_read_scope(control)
	OverworldRules.end_normalized_read_scope(control)
	var result:Dictionary=TownRules.build_active_town(control,id)
	check(result.ok,"independent build control rejected: "+id)
	OverworldRules.begin_normalized_read_scope(control)
	TownRules.begin_read_scope(control)
	var recap:Dictionary=TownRules.build_town_action_recap(control,"build","build:"+id,action,result,before)
	TownRules.end_read_scope(control)
	OverworldRules.end_normalized_read_scope(control)
	if recap.get("active",false): control.flags["last_town_action_recap"]=recap.duplicate(true)
	OverworldRules._runtime_normalized_signatures=cache
	return normalized(control.to_dict())
func paid_controls(shell,templates:Array)->void:
	# Small isolated prerequisites/resource fixtures, not earned campaign claims.
	var preferred:Dictionary={"faction_embercourt":"building_lantern_archive","faction_mireclaw":"building_gorefen_ring","faction_sunvault":"building_lens_gallery","faction_thornwake":"building_thornwake_worldroot_gate","faction_brasshollow":"building_brasshollow_boiler_cathedral","faction_veilmourn":"building_veilmourn_drowned_map_room"}
	for template in templates:
		var created=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
		var fixture:Dictionary=created.to_dict()
		var id:String=preferred[template.faction_id]
		check(id in template.buildable_building_ids,"paid fixture target not in catalog: "+template.id)
		for town in fixture.overworld.towns:
			if town.placement_id!="riverwatch_hold": continue
			town.town_id=template.id
			town.built_buildings=template.starting_building_ids.duplicate()
			for prerequisite in ContentService.get_building(id).get("requires",[]):
				OverworldRules._append_building_with_requirements(town.built_buildings,prerequisite)
			town.last_build_day=0
		for resource in fixture.overworld.resources: fixture.overworld.resources[resource]=100000
		var session=SessionState.restore_session(fixture)
		OverworldRules.set_active_town_visit(session,"riverwatch_hold")
		session.game_state="town"
		shell._session=session
		shell._refresh()
		var stage=shell.get_node("%TownStage")
		var actions:Array=TownRules.get_build_actions(session).filter(func(a):return a.id=="build:"+id and not a.get("disabled",true) and a.get("direct_affordable",true))
		check(actions.size()==1,"paid order unavailable: "+template.id)
		if actions.size()!=1: continue
		check(not stage.validation_building_hotspot_summary(id).visible,"unbuilt layer visible: "+template.id)
		var expected:Dictionary=expected_build(session,id,actions[0])
		shell._select_build_action("build:"+id)
		shell._on_confirm_build_pressed()
		while shell.get_node("%TownActionInputBlocker").visible: await get_tree().process_frame
		check(normalized(session.to_dict())==expected,"UI build differs from full rule/recap control: "+template.id)
		check(stage.validation_building_hotspot_summary(id).visible,"paid layer missing: "+template.id)
		check(TownRules.get_active_town(session).last_build_day==session.day,"daily build limit not consumed: "+template.id)
		shell._close_town_catalog(false)
		var before:Dictionary=normalized(session.to_dict())
		check(SaveService.save_session(session.to_dict(),3)!="","save failed: "+template.id)
		session=SessionState.restore_session(SaveService.load_session(3))
		check(normalized(session.to_dict())==before,"complete save/resume changed: "+template.id)
		shell._session=session
		shell._refresh()
		check(stage.validation_building_hotspot_summary(id).visible,"saved layer missing: "+template.id)
		rows.append({"paid_fixture":template.id,"building":id,"complete_state_control":true})
func exposed_patch(shell,stage,button)->Vector2:
	var layout:Dictionary=shell.validation_owner_town_layout_snapshot()
	for y in [0.55,0.65,0.75,0.45,0.35,0.25,0.85,0.15]:
		for x in [0.5,0.4,0.6,0.3,0.7,0.2,0.8,0.1,0.9]:
			var center:Vector2=Vector2(x,y)*button.size
			var exposed:=true
			for offset in [Vector2.ZERO,Vector2(-3,0),Vector2(3,0),Vector2(0,-3),Vector2(0,3)]:
				var point:Vector2=center+offset
				var screen:Vector2=button.get_global_transform_with_canvas()*point
				if not button._has_point(point) or layout.footer_rect.has_point(screen) or layout.sidebar_rect.has_point(screen) or layout.header_rect.has_point(screen):
					exposed=false
					break
				if stage._main_building_hotspot.get_global_rect().has_point(screen):
					exposed=false
					break
				for other in stage._building_hotspots.values():
					if other==button or not other.visible or other.get_index()<button.get_index(): continue
					if other._has_point(other.get_global_transform_with_canvas().affine_inverse()*screen):
						exposed=false
						break
				if not exposed: break
			if exposed: return button.get_global_transform_with_canvas()*center
	return Vector2(-1,-1)
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
	var templates:Array=JSON.parse_string(FileAccess.get_file_as_string("res://content/towns.json")).items
	var inspected:Dictionary={}
	for template in templates:
		var catalog:Array=template.starting_building_ids.duplicate()
		for id in template.buildable_building_ids:
			if id not in catalog: catalog.append(id)
		for town in session.overworld.towns:
			if town.placement_id=="riverwatch_hold":
				town.town_id=template.id
				town.built_buildings=catalog.duplicate()
		shell._refresh()
		for i in range(3): await get_tree().process_frame
		await click(stage._main_building_hotspot.get_global_rect().get_center())
		check(shell._town_catalog_is_open() and shell._town_catalog_mode=="build","main building did not open construction: "+template.id)
		shell._close_town_catalog(false)
		if OS.get_environment("TOWN_COMPOSITION_OLD_MAIN_HITBOX")=="1" and template.faction_id=="faction_veilmourn":
			var old:Dictionary=stage._project_normalized_source_rect(Rect2(.29,.15,.19,.52),stage._town_scene_rect())
			stage._main_building_hotspot.position=old.destination_rect.position
			stage._main_building_hotspot.size=old.destination_rect.size
		var before:Dictionary=session.to_dict().duplicate(true)
		var entries:Array=stage._town_building_scene_entries(stage._town_scene_rect())
		for entry in entries:
			var id:String=entry.visible_building_id
			if id=="" or id=="building_town_hall": continue
			var button=stage._building_hotspots[id]
			var patch:Vector2=exposed_patch(shell,stage,button)
			check(patch.x>=0,"no exposed painted input patch: "+template.id+"/"+id)
			if patch.x>=0:
				await click(patch)
				var clicked:Dictionary=shell.validation_building_information_snapshot(id)
				check(clicked.open and clicked.title==clicked.expected_title,"painted pointer opened wrong dialog: "+template.id+"/"+id)
				shell._close_town_catalog(false)
		for id in catalog:
			if id=="building_town_hall": continue
			var key:String=template.faction_id+"/"+id
			if inspected.has(key): continue
			inspected[key]=true
			stage._town.built_buildings=["building_town_hall",id]
			stage._sync_building_hotspots()
			stage.queue_redraw()
			await get_tree().process_frame
			var summary:Dictionary=stage.validation_building_hotspot_summary(id)
			check(summary.visible and summary.aligned and summary.focus_mode==Control.FOCUS_ALL,"hotspot alignment/focus: "+key)
			var art:Dictionary=stage._building_scene_art_manifest.factions[template.faction_id][id]
			var rect:Array=art.normalized_rect
			var texture:Texture2D=stage._town_building_texture(id)
			check(absf(rect[2]*1600.0/(rect[3]*900.0)-texture.get_width()/float(texture.get_height()))<0.005,"distorted raster: "+key)
			var button=stage._building_hotspots[id]
			check(exposed_patch(shell,stage,button).x>=0,"isolated building blocked by scenery/UI: "+key)
			button.grab_focus()
			check(button.has_focus(),"keyboard focus missing: "+key)
			button.pressed.emit()
			var info:Dictionary=shell.validation_building_information_snapshot(id)
			check(info.open and info.title==info.expected_title and info.description==info.expected_description,"wrong building information: "+key)
			shell._close_town_catalog(false)
		check(session.to_dict()==before,"view/info changed gameplay: "+template.id)
		rows.append({"town":template.id,"catalog":catalog.size()})
	check(inspected.size()==173,"not all 173 authored layers exercised")
	check(templates.size()==32,"not all 32 towns exercised")
	if OS.get_environment("TOWN_COMPOSITION_OLD_MAIN_HITBOX")!="1": await paid_controls(shell,templates)
	shell.queue_free()
	for i in range(3): await get_tree().process_frame
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"rows":rows,"unique_layers":inspected.size()}))
	get_tree().quit(0 if failures.is_empty() else 1)
'''


def main():
    runner.OUTPUT = OUTPUT
    runner.SCRIPT = SCRIPT
    runner.run_probe = run_probe
    runner.probe_environment = probe_environment
    return runner.main()


if __name__ == '__main__':
    raise SystemExit(main())
