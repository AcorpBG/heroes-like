#!/usr/bin/env python3
"""Coordinated UI acceptance through actual scenes and immutable release packs."""
import sys
import battle_readability_regression as runner

ROOT = runner.ROOT
OUTPUT = ROOT / '.artifacts/graphical-usability-20260917'
run_probe = runner.run_probe
probe_environment = runner.probe_environment
COMPILED_OWNERS = (
    'scenes/battle/BattleBoardView.gdc', 'scenes/battle/BattleMessageLog.gdc',
    'scenes/battle/BattleShell.gdc', 'scenes/shared/ArmyStackBar.gdc',
    'scenes/shared/ArmySlotButton.gdc', 'scenes/shared/ScoutInspectionDialog.gdc',
    'scenes/overworld/OverworldMapView.gdc', 'scenes/overworld/OverworldShell.gdc',
    'scenes/town/TownStageView.gdc', 'scenes/town/TownShell.gdc',
    'scripts/ui/OverworldInspection.gdc', 'scripts/ui/FrontierVisualKit.gdc')
SCRIPT = runner.SCRIPT.split('func _ready()')[0] + r'''
const Inspection = preload("res://scripts/ui/OverworldInspection.gd")
const Levels = preload("res://scripts/core/OverworldLevelRules.gd")
const Kit = preload("res://scripts/ui/FrontierVisualKit.gd")
var requested := Vector2i(1280,720)
var operations := []
var preview_count := 0
var preview_factions := []
func _ready() -> void: call_deferred("run")
func settle() -> void:
	for i in range(6): await get_tree().process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await settle()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check(image.get_size()==requested,"capture resolution: "+label)
	image.save_png(out.path_join(label+".png"))
func click(control: Control) -> void:
	if DisplayServer.get_name()=="headless":
		if control is Button: control.pressed.emit()
		return
	var point := control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=get_viewport().get_final_transform()*point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await settle()
func drag(source: Control, target: Control) -> void:
	var start:=get_viewport().get_final_transform()*source.get_global_rect().get_center()
	var finish:=get_viewport().get_final_transform()*target.get_global_rect().get_center()
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=start
	Input.parse_input_event(press)
	await get_tree().process_frame
	var previous:=start
	for step in range(1,9):
		var motion:=InputEventMouseMotion.new()
		motion.position=start.lerp(finish,step/8.0)
		motion.relative=motion.position-previous
		motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		previous=motion.position
		await get_tree().process_frame
	press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT;press.pressed=false;press.position=finish
	Input.parse_input_event(press)
	await settle()
func battle() -> void:
	var live = SessionState.set_active_session(fixture())
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	add_child(shell)
	await settle()
	var log_control = shell._message_log
	for i in range(205): log_control.append_message("Action %d · River Guard strikes; 2 casualties"%i)
	await settle()
	check(log_control.entries.size()==200 and log_control.entries[0].begins_with("Action 5"),"log bound/order")
	check(not log_control.expanded and not log_control.history.visible,"log does not start compact")
	check(log_control.size.y<=50,"collapsed log wastes battlefield space")
	check(log_control.latest.text.begins_with("Action 204"),"latest event absent")
	var retained: Array=log_control.entries.duplicate()
	await capture("battle-compact")
	if DisplayServer.get_name()=="headless": log_control.set_expanded(true)
	else: await click(log_control.toggle)
	await settle()
	check(log_control.expanded and log_control.history.visible,"log click did not expand")
	check("BattleHistory" in shell._last_battle_keyboard_focus_cycle_names,"expanded history missing from keyboard navigation")
	if DisplayServer.get_name()!="headless":
		log_control.jump_latest.grab_focus()
		var key:=InputEventKey.new()
		key.keycode=KEY_TAB;key.pressed=true
		Input.parse_input_event(key)
		await get_tree().process_frame
		key=InputEventKey.new();key.keycode=KEY_TAB;key.pressed=false
		Input.parse_input_event(key)
		check(log_control.history.has_focus(),"Tab cannot enter expanded history")
	check(log_control.entries==retained,"expand loses history")
	var bar=log_control.history.get_v_scroll_bar()
	bar.value=0
	log_control.append_message("Another action")
	await settle()
	check(bar.value==0,"new action interrupts scrolling")
	check(not log_control.get_global_rect().intersects(shell._battle_board_view.get_global_rect()),"log overlaps battlefield")
	check(Rect2(Vector2.ZERO,Vector2(requested)).encloses(log_control.get_global_rect()),"expanded log clips")
	await capture("battle-expanded")
	log_control.set_expanded(false)
	check(log_control.history.text.ends_with("Another action"),"collapse loses last event")
	check(shell._battle_board_view._stack_caption_label({"name":"Blackbranchguard"})!="…","long single-word unit has no name")
	shell.queue_free()
	await settle()
func army() -> void:
	var control=load("res://scenes/shared/ArmyStackBar.gd").new()
	add_child(control)
	control.position=Vector2(24,24)
	control.size=Vector2(310,260)
	var holders:=[]
	for holder_id in ["hero","garrison"]:
		var slots:=[]
		for index in range(7):
			slots.append({"holder_id":holder_id,"slot_index":index,"occupied":index<2,"unit_id":"unit_river_guard" if index==0 else "unit_crossbow_levy","unit_name":"River Guard" if index==0 else "Crossbow Levy","count":11 if index==0 else 4,"battle_icon":ContentService.get_unit_art("unit_river_guard").get("battle_icon","")})
		holders.append({"holder_id":holder_id,"holder_label":"Riverwatch garrison" if holder_id=="garrison" else "Hero","capacity_valid":true,"slots":slots})
	control.configure(holders)
	control.operation_requested.connect(func(a,b,c,d,e):operations.append([a,b,c,d,e]))
	await settle()
	await click(control._slot_buttons[control._slot_key("hero",0)])
	control._mode_buttons.exact.pressed.emit()
	control._quantity.value=3
	check(control._amount_token=="3" and control._quantity_row.visible,"exact split quantity")
	var preview:Dictionary=control.destination_preview("garrison",2)
	check(preview.allowed and preview.amount==3 and "garrison" in preview.recipient,"exact recipient preview")
	check(not control.destination_preview("garrison",1).allowed,"partial mixed-unit swap admitted")
	check(control._slot_buttons[control._slot_key("garrison",2)].get_meta("legal_destination"),"legal destination not highlighted")
	if DisplayServer.get_name()!="headless":
		await drag(control._slot_buttons[control._slot_key("hero",0)],control._slot_buttons[control._slot_key("garrison",2)])
		check(operations.size()==1 and operations[0]==["hero",0,"garrison",2,"3"],"physical pointer drag did not route exact transfer")
		operations.clear()
	var payload:Dictionary=control.begin_slot_drag("hero",0)
	check(control.can_drop_stack(payload,"garrison",2),"legal drag rejected")
	control.drop_stack(payload,"garrison",2)
	check(operations.size()==1 and operations[0]==["hero",0,"garrison",2,"3"],"drag routing/count")
	control.configure(holders)
	check(not control.can_drop_stack(payload,"garrison",2),"stale drag accepted")
	payload=control.begin_slot_drag("hero",0)
	payload.bar=-1
	check(not control.can_drop_stack(payload,"garrison",2),"foreign drag accepted")
	control._mode_buttons.all.pressed.emit()
	check(control.destination_preview("garrison",1).allowed,"whole-stack swap rejected")
	control._mode_buttons.half.pressed.emit()
	check(control.destination_preview("garrison",2).amount==5,"half split rounding changed")
	control._mode_buttons.exact.pressed.emit()
	control._quantity.value=3
	control._preview_destination("garrison",2)
	await capture("army-exact-preview")
	control.configure(holders,false)
	check(control.begin_slot_drag("hero",0).is_empty(),"disabled bar allows drag")
	control.queue_free()
	await settle()
func overworld() -> void:
	var session=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	session=SessionState.set_active_session(session)
	var shell=load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await settle()
	var before:Dictionary=session.to_dict().duplicate(true)
	var rows:=Inspection.highlight_rows(session,0)
	check(not rows.is_empty(),"no visible interactable highlights")
	for row in rows:
		check(row.level==0 and OverworldRules.is_tile_visible(session,row.tile.x,row.tile.y,0),"highlight leaks fog/level")
	var hidden:=Vector2i(-1,-1)
	var map_size:Vector2i=OverworldRules.derive_map_size(session)
	for y in range(map_size.y):
		for x in range(map_size.x):
			if not OverworldRules.is_tile_visible(session,x,y,0): hidden=Vector2i(x,y)
	var hidden_report:=Inspection.inspect_tile(session,hidden,0)
	check(not hidden_report.disclosed and hidden_report.stacks.is_empty() and hidden_report.terrain=="Unknown","hidden inspection exposes content")
	# Independently plant a duplicate identity on another level; it must not
	# inherit disclosure merely because its x/y matches a scouted surface tile.
	var other:Dictionary=session.overworld.encounters[0].duplicate(true)
	other.level=1
	check(not Inspection.visible_record(session,other,0),"same coordinates disclose other level")
	check(session.to_dict()==before,"inspection/highlights mutate session")
	var sample_session=Store.new_session_data()
	sample_session.from_dict(session.to_dict().duplicate(true))
	sample_session.overworld.encounters=[]
	sample_session.overworld.resource_nodes=[]
	sample_session.overworld.artifact_nodes=[]
	sample_session.overworld.towns=[]
	var point:Vector2i=rows[0].tile
	var persistent_id:=""
	var repeatable_id:=""
	for site in ContentService.load_json("res://content/resource_sites.json").items:
		if persistent_id.is_empty() and site.get("persistent_control",false): persistent_id=site.id
		if repeatable_id.is_empty() and OverworldRules._resource_site_is_repeatable(site) and not site.get("persistent_control",false): repeatable_id=site.id
	check(not persistent_id.is_empty() and not repeatable_id.is_empty(),"missing status fixture content")
	sample_session.overworld.resource_nodes=[
		{"placement_id":"hint-visited","site_id":persistent_id,"x":point.x,"y":point.y,"collected":true,"collected_by_faction_id":"player"},
		{"placement_id":"hint-exhausted","site_id":repeatable_id,"x":point.x,"y":point.y,"collected":true,"collected_day":sample_session.day},
		{"placement_id":"hint-available","site_id":repeatable_id,"x":point.x,"y":point.y,"collected":false}]
	var states:=Inspection.highlight_rows(sample_session,0)
	for expected in ["Visited","Exhausted","Available"]:
		check(states.any(func(row):return row.state==expected),"missing interaction state: "+expected)
	shell._highlight_interactions_button.button_pressed=true
	await settle()
	await get_tree().create_timer(0.12).timeout
	if DisplayServer.get_name()!="headless": check(shell._map_view._interaction_highlights,"toggle does not activate highlights")
	check(Rect2(Vector2.ZERO,Vector2(requested)).encloses(shell._end_turn_button.get_global_rect()),"overworld footer clips")
	check(Rect2(Vector2.ZERO,Vector2(requested)).encloses(shell._inspect_tile_button.get_global_rect()),"scout controls clip")
	await capture("overworld-sites")
	if DisplayServer.get_name()!="headless":
		shell._highlight_interactions_button.button_pressed=false
		for pressed in [true,false]:
			var alt:=InputEventKey.new()
			alt.keycode=KEY_ALT;alt.physical_keycode=KEY_ALT;alt.pressed=pressed
			Input.parse_input_event(alt)
			await get_tree().create_timer(0.12).timeout
			check(shell._map_view._interaction_highlights==pressed,"hold/release Alt does not control hints")
	var encounter:Dictionary={}
	for item in session.overworld.encounters:
		if Inspection.visible_record(session,item,0): encounter=item;break
	if encounter.is_empty():
		# Reveal one contact with the actual rule API, only as test setup.
		encounter=session.overworld.encounters[0]
		var fog:Dictionary=OverworldRules.fog_for_level(session,0)
		OverworldRules._apply_site_reveal(fog.explored_tiles,encounter,2,map_size)
	var tile:=Vector2i(int(encounter.x),int(encounter.y))
	shell._set_selected_tile(tile,false)
	shell._refresh()
	await settle()
	before=session.to_dict().duplicate(true)
	await click(shell._inspect_tile_button)
	await settle()
	check(shell._scout_dialog.visible,"inspect button did not open modal")
	var report:Dictionary=shell._scout_dialog.snapshot
	check(report.disclosed and not report.stacks.is_empty() and report.encounter_key==OverworldRules.encounter_key(encounter),"scouted identity/army missing")
	check(shell._overworld_gameplay_movement_blocked_reason()=="scout_inspection_open","inspection permits movement")
	check(session.to_dict()==before,"opening inspection commits gameplay")
	var battle_payload:Dictionary=BattleRules.create_battle_payload(session,encounter)
	check(report.terrain==String(battle_payload.terrain).capitalize(),"inspection terrain differs from actual battle")
	var original_biome:Variant=encounter.get("terrain")
	encounter.terrain="unrelated_world_biome"
	check(Inspection.inspect_tile(session,tile,0).terrain==String(battle_payload.terrain).capitalize(),"placement biome overrides actual battle terrain")
	if original_biome==null: encounter.erase("terrain")
	else: encounter.terrain=original_biome
	await capture("overworld-scout-report")
	Kit.hide_exclusive_dialog(shell._scout_dialog)
	shell.queue_free()
	await settle()
func towns() -> void:
	var session=ScenarioFactory.create_session("river-pass","normal",SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var stage=load("res://scenes/town/TownStageView.gd").new()
	add_child(stage)
	stage.size=Vector2(requested)
	var all_towns:Array=ContentService.load_json("res://content/towns.json").items
	for template in all_towns:
		var town:Dictionary={"town_id":template.id,"placement_id":"preview-"+template.id,"owner":"player","built_buildings":[]}
		stage.set_precomputed_town_state(session,{"town":town,"town_template":template,"faction":ContentService.get_faction(template.faction_id)})
		var before:Dictionary=session.to_dict().duplicate(true)
		for building_id in stage._town_building_catalog_ids():
			stage.set_construction_preview(building_id)
			var preview:Dictionary=stage.construction_preview_snapshot()
			var entries:Array=stage._town_building_scene_entries(stage._town_scene_rect())
			check(entries.all(func(entry):return entry.visible_building_id==""),"preview entered built entries: "+building_id)
			check(not preview.is_empty(),"catalog building has no preview: "+building_id)
			if preview.is_empty() or preview.get("embedded_in_base",false): continue
			preview_count+=1
			check(preview.visible_building_id==building_id and stage._town_building_texture(building_id)!=null,"preview identity/art: "+building_id)
			check(not stage._building_hotspots.has(building_id),"preview gains active hotspot: "+building_id)
			stage._town.built_buildings=[building_id]
			var built:Array=stage._town_building_scene_entries(stage._town_scene_rect()).filter(func(entry):return entry.visible_building_id==building_id)
			check(built.size()==1 and built[0].destination_rect==preview.destination_rect and built[0].texture_region_ratio==preview.texture_region_ratio,"preview differs from built rectangle/crop: "+building_id)
			stage._town.built_buildings=[]
			if template.faction_id not in preview_factions:
				preview_factions.append(template.faction_id)
				await capture("town-preview-"+template.faction_id)
		check(session.to_dict()==before,"preview changes save/rules: "+template.id)
	stage.set_construction_preview("")
	check(stage.construction_preview_snapshot().is_empty(),"clear preview left a ghost")
	check(preview_factions.size()==6 and preview_count>100,"insufficient faction/building preview coverage")
	stage.queue_free()
	await settle()
	var town:Dictionary=session.overworld.towns[0]
	var entrance:Dictionary=Levels.town_entrance(town)
	session.overworld.hero_position=entrance.duplicate(true)
	HeroCommandRules.hero_by_id(session,String(session.overworld.active_hero_id)).position=entrance.duplicate(true)
	HeroCommandRules.normalize_session(session)
	check(OverworldRules.set_active_town_visit(session,String(town.placement_id)).ok,"town fixture visit")
	session.game_state="town"
	session=SessionState.set_active_session(session)
	var shell=load("res://scenes/town/TownShell.tscn").instantiate()
	add_child(shell)
	await settle()
	shell._on_open_build_catalog_pressed()
	await settle()
	var before:Dictionary=session.to_dict().duplicate(true)
	var cards:Array=shell._build_actions.get_children()
	for card in cards:
		var button=card.get_child(0).get_child(0)
		var id:String=String(button.get_meta("catalog_entry_id","")).trim_prefix("build:")
		if id in TownRules.get_active_town(session).built_buildings: continue
		button.focus_entered.emit()
		check(shell._town_stage_view._construction_preview_id==id,"catalog focus did not preview actual building")
		break
	check(Rect2(Vector2.ZERO,Vector2(requested)).encloses(shell._town_catalog_panel.get_global_rect()),"construction ledger clips")
	await capture("town-construction-ledger")
	await click(shell._construction_peek_button)
	await settle()
	check(shell._construction_scene_only and not shell._town_catalog_scroll.visible,"scenic placement view did not fold ledger")
	check(Rect2(Vector2.ZERO,Vector2(requested)).encloses(shell._town_catalog_panel.get_global_rect()),"folded construction controls clip")
	await capture("town-placement-preview")
	check(session.to_dict()==before,"catalog preview mutates session")
	var selected_id:String=shell._selected_build_action_id.trim_prefix("build:")
	var preview:Dictionary=shell._town_stage_view.construction_preview_snapshot()
	var direct=Store.new_session_data()
	direct.from_dict(session.to_dict().duplicate(true))
	var result:Dictionary=TownRules.build_active_town(direct,selected_id)
	check(result.ok,"selected real construction is not affordable")
	await click(shell._confirm_build_button)
	await settle()
	check(selected_id in TownRules.get_active_town(session).built_buildings,"scenic preview Build did not commit selected building")
	check(TownRules.get_active_town(session).built_buildings==TownRules.get_active_town(direct).built_buildings and session.overworld.resources==direct.overworld.resources,"preview build differs from authoritative cost/progression")
	var built:Array=shell._town_stage_view._town_building_scene_entries(shell._town_stage_view._town_scene_rect()).filter(func(entry):return entry.visible_building_id==selected_id)
	check(built.size()==1 and built[0].destination_rect==preview.get("destination_rect",Rect2()),"actual built art differs from preview position")
	await capture("town-constructed")
	shell._close_town_catalog()
	check(shell._town_stage_view._construction_preview_id.is_empty(),"catalog close retains ghost")
	shell.queue_free()
	await settle()
func run() -> void:
	out=OS.get_environment("BATTLE_READABILITY_OUT")
	var parts:=OS.get_environment("TOWN_OVERLAY_RESOLUTION").split("x")
	requested=Vector2i(int(parts[0]),int(parts[1]))
	SettingsService.set_presentation_mode("windowed")
	SettingsService.set_presentation_resolution(OS.get_environment("TOWN_OVERLAY_RESOLUTION"))
	get_tree().root.size=requested
	get_tree().root.content_scale_size=requested
	if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(requested)
	await battle()
	await army()
	await overworld()
	await towns()
	print("BATTLE_READABILITY_REPORT "+JSON.stringify({"ok":failures.is_empty(),"checks":checks,"failures":failures,"previews":preview_count,"factions":preview_factions,"resolution":[requested.x,requested.y]}))
	get_tree().quit(0 if failures.is_empty() else 1)
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
